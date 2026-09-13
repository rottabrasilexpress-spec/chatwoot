module RottaCalculator
  class CalculateService
    # Keep the synchronous request below the reverse-proxy limit while allowing
    # the configured model's normal response window to complete.
    AI_WAIT_TIMEOUT = 12.5

    def initialize(payload, routes_client: nil, ai_client: OpenRouterClient.new, ai_timeout: AI_WAIT_TIMEOUT)
      @payload = payload.stringify_keys
      @routes_client = routes_client || ResilientRoutesClient.new
      @ai_client = ai_client
      @ai_timeout = ai_timeout
    end

    def call
      freight = @payload.fetch('freight', {}).stringify_keys
      inventory = @payload.fetch('inventory', {}).stringify_keys
      pricing_input = @payload.fetch('pricing', {}).stringify_keys
      parsed = PreBudgetParser.new(
        reading_text: @payload['reading_text'],
        freight: freight,
        inventory: inventory,
        services: @payload['services']
      ).call
      origin = freight['origin'].presence || parsed['origin'].to_s.strip
      destination = freight['destination'].presence || parsed['destination'].to_s.strip
      raise ArgumentError, 'Origem e destino são obrigatórios' if origin.blank? || destination.blank?

      # Route lookup and factual extraction are independent. Running them in
      # parallel keeps the synchronous request below the reverse-proxy limit.
      # The AI receives route facts, never the large encoded polyline: the
      # polyline is for the map and is not useful for language extraction.
      route_lookup = Thread.new { @routes_client.call(origin: origin, destination: destination) }
      ai_lookup = Thread.new do
        @ai_client.call(
          'reading_text' => @payload['reading_text'].to_s,
          'freight' => freight,
          'services' => @payload['services'],
          'inventory' => inventory,
          'parsed_data' => parsed,
          'inventory_catalog' => InventoryCatalog.all.map { |entry| { 'name' => entry.name, 'aliases' => entry.aliases, 'mounted_m3' => entry.mounted_m3, 'disassembled_m3' => entry.disassembled_m3, 'weight_kg' => entry.weight_kg, 'disassemblable' => entry.disassemblable } },
          'route' => { 'origin' => origin, 'destination' => destination, 'toll_status' => 'disabled', 'tolls' => 0.0 },
          'toll' => { 'enabled' => false, 'calculated' => false }
        )
      end
      route = route_lookup.value
      ai = wait_for_ai(ai_lookup)
      extracted = parsed.deep_merge(ai['extracted_data'].is_a?(Hash) ? ai['extracted_data'].deep_stringify_keys : {})
      extracted['client_name'] = parsed['client_name'] if parsed['client_name'].present?
      extracted['date'] = parsed['date'] if parsed['date'].present?
      extracted['origin'] = parsed['origin'] if parsed['origin'].present?
      extracted['destination'] = parsed['destination'] if parsed['destination'].present?
      resolved_inventory = InventoryResolver.new(ai_estimates: ai['inventory_estimates']).call(parsed.dig('inventory', 'items'))
      extracted['inventory'] = resolved_inventory
      extracted['services'] = parsed['services'].deep_merge(ai['services'].is_a?(Hash) ? ai['services'].deep_stringify_keys : {})
      pricing = PricingEngine.new(route: route, parsed_data: extracted, pricing: pricing_input).call
      proposal = ProposalBuilder.call(freight: freight.merge(extracted.slice('client_name', 'date', 'origin', 'destination')), route: route, inventory: resolved_inventory, pricing: pricing)

      {
        'route' => "#{origin} → #{destination}",
        'distance_km' => route['distance_km'],
        'duration_minutes' => route['duration_minutes'],
        'truck_duration_minutes' => pricing['truck_duration_minutes'],
        'truck_duration_hours' => pricing['truck_duration_hours'],
        'selected_services' => selected_services(extracted),
        'price' => pricing.dig('selected', 'final_price'),
        'api_status' => 'complete',
        'ai_status' => ai['status'],
        'toll_status' => 'disabled',
        'route_provider' => route['provider'],
        'route_polyline' => route['polyline'],
        'proposal' => proposal,
        'summary' => ai['summary'].to_s,
        'missing_information' => missing_information(extracted, ai),
        'extracted_data' => extracted,
        'inventory' => resolved_inventory,
        'pricing' => pricing,
        'pricing_note' => 'Valores calculados pelo motor determinístico; pedágios permanentemente desativados.'
      }
    end

    private

    def wait_for_ai(thread)
      return thread.value.stringify_keys.merge('status' => 'complete') if thread.join(@ai_timeout)

      thread.kill
      thread.join(0.1)
      Rails.logger.warn('[RottaCalculator] OpenRouter excedeu a janela síncrona; seguindo com leitura determinística.')
      degraded_ai_response
    rescue StandardError => e
      Rails.logger.warn("[RottaCalculator] OpenRouter indisponível nesta tentativa: #{e.class}")
      degraded_ai_response
    end

    def degraded_ai_response
      {
        'status' => 'degraded',
        'summary' => 'A leitura assistida por IA excedeu a janela de resposta; os dados determinísticos foram preservados.',
        'missing_information' => ['Revisar a leitura assistida por IA quando o provedor estiver disponível.'],
        'extracted_data' => {},
        'inventory_estimates' => [],
        'services' => {}
      }
    end

    def selected_services(extracted)
      services = extracted.fetch('services', {}).to_h.stringify_keys
      labels = []
      labels << 'Ajudantes' if services.dig('helpers', 'origin').to_i.positive? || services.dig('helpers', 'destination').to_i.positive?
      labels << 'Desmontagem e montagem' if services.dig('assembly', 'requested')
      labels << 'Material e embalagem' if services.dig('materials', 'selected')
      labels
    end

    def missing_information(extracted, ai)
      missing = Array(ai['missing_information']).map(&:to_s)
      missing << 'Origem' if extracted['origin'].blank?
      missing << 'Destino' if extracted['destination'].blank?
      missing << 'Data pretendida' if extracted['date'].blank?
      missing << 'Revisar itens sem correspondência no catálogo' if extracted.dig('inventory', 'manual_review')
      missing.uniq
    end
  end
end
