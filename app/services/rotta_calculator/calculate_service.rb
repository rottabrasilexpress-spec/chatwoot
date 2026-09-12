module RottaCalculator
  class CalculateService
    def initialize(payload, routes_client: GoogleRoutesClient.new, ai_client: OpenRouterClient.new)
      @payload = payload.stringify_keys
      @routes_client = routes_client
      @ai_client = ai_client
    end

    def call
      freight = @payload.fetch('freight', {}).stringify_keys
      services = Array(@payload['services']).map(&:stringify_keys).select { |service| service['selected'] }
      inventory = @payload.fetch('inventory', {}).stringify_keys
      origin = freight['origin'].to_s.strip
      destination = freight['destination'].to_s.strip
      raise ArgumentError, 'Origem e destino são obrigatórios' if origin.blank? || destination.blank?

      route = @routes_client.call(origin: origin, destination: destination)
      ai = @ai_client.call(
        'reading_text' => @payload['reading_text'].to_s,
        'freight' => freight,
        'services' => services,
        'inventory' => inventory,
        'route' => route,
        'toll' => { 'enabled' => false, 'calculated' => false }
      ).stringify_keys

      {
        'route' => "#{origin} → #{destination}",
        'distance_km' => route['distance_km'],
        'duration_minutes' => route['duration_minutes'],
        'selected_services' => services.map { |service| service['label'] }.compact,
        'price' => numeric_price_or_nil(ai['price']),
        'api_status' => 'complete',
        'ai_status' => 'complete',
        'toll_status' => 'disabled',
        'proposal' => ai['proposal'].presence || fallback_proposal(freight, inventory, route),
        'summary' => ai['summary'].to_s,
        'missing_information' => Array(ai['missing_information']),
        'extracted_data' => ai['extracted_data'].is_a?(Hash) ? ai['extracted_data'] : {},
        'pricing_note' => ai['pricing_note'].presence || 'Nenhuma tabela de preços foi fornecida.'
      }
    end

    private

    def numeric_price_or_nil(value)
      return if value.blank?
      return value.to_f if value.is_a?(Numeric)

      value.to_s.gsub(',', '.').to_f if value.to_s.match?(/\A\d+(?:[.,]\d+)?\z/)
    end

    def fallback_proposal(freight, inventory, route)
      [
        'Rotta Brasil Express',
        "Cliente: #{freight['client_name'].presence || 'A definir'}",
        "Data prevista: #{freight['date'].presence || 'A definir'}",
        "Rota: #{freight['origin']} → #{freight['destination']}",
        "Distância estimada: #{route['distance_km']} km",
        "Tempo estimado: #{route['duration_minutes']} min",
        "Inventário: #{inventory['item_count'] || 0} item(ns)",
        'Preço: falta a tabela de preços da empresa.'
      ].join("\n")
    end
  end
end
