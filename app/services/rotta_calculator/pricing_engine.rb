module RottaCalculator
  class PricingEngine
    MARGIN_DEFAULT_PERCENT = 35.0
    FLOOR_PROFIT = 600.0
    MIN_ADJUSTMENT_STEP = 0.05
    DEFAULT_ADJUSTMENT_STEP = 0.25
    CARDS = [
      { 'id' => 'economica', 'name' => 'Econômica', 'tariff_per_km' => 1.50, 'description' => 'Rotas flexíveis' },
      { 'id' => 'padrao', 'name' => 'Padrão', 'tariff_per_km' => 2.00, 'description' => 'Operação padrão' },
      { 'id' => 'equilibrada', 'name' => 'Equilibrada', 'tariff_per_km' => 2.50, 'description' => 'Equilíbrio comercial' },
      { 'id' => 'prioritaria', 'name' => 'Prioritária', 'tariff_per_km' => 2.75, 'description' => 'Coleta prioritária' },
      { 'id' => 'premium', 'name' => 'Premium', 'tariff_per_km' => 3.00, 'description' => 'Exclusividade e urgência' },
      { 'id' => 'rota_ruim', 'name' => 'Rota ruim', 'tariff_per_km' => 3.50, 'description' => 'Norte, Nordeste, MT ou rota crítica' }
    ].freeze

    def initialize(route:, parsed_data:, pricing: {})
      @route = route.to_h.stringify_keys
      @parsed_data = parsed_data.to_h.stringify_keys
      @pricing = pricing.to_h.stringify_keys
    end

    def call
      distance = non_negative(@route['distance_km'])
      margin = [[number(@pricing['margin_percent'], MARGIN_DEFAULT_PERCENT), 0.0].max, 95.0].min / 100.0
      adjustment = number(@pricing['adjustment_per_km'], 0.0)
      step = [number(@pricing['adjustment_step'], DEFAULT_ADJUSTMENT_STEP), MIN_ADJUSTMENT_STEP].max
      services = service_costs
      selected_id = @pricing['selected_card_id'].presence || 'padrao'
      cards = CARDS.map do |card|
        build_card(card, distance, margin, adjustment, services)
      end
      selected = cards.find { |card| card['id'] == selected_id } || cards[1]

      {
        'cards' => cards,
        'selected_card_id' => selected['id'],
        'selected' => selected,
        'services' => services,
        'margin_percent' => (margin * 100).round(2),
        'adjustment_per_km' => adjustment.round(2),
        'adjustment_step' => step.round(2),
        'tolls' => 0.0,
        'toll_status' => 'disabled',
        'truck_duration_minutes' => (@route['duration_minutes'].to_f * 1.25).ceil,
        'truck_duration_hours' => ((@route['duration_minutes'].to_f * 1.25) / 60.0).round(2)
      }
    end

    private

    def build_card(card, distance, margin, adjustment, services)
      base_tariff = [number(card['tariff_per_km'], 0.0), 0.0].max
      freight_cost = distance * base_tariff
      initial_freight_price = margin >= 1.0 ? freight_cost : freight_cost / [1.0 - margin, 0.05].max
      freight_only_before_adjustment = [initial_freight_price, freight_cost + FLOOR_PROFIT].max
      freight_only_price = [freight_only_before_adjustment + (distance * adjustment), 0.0].max
      final_price = freight_only_price + services['total']
      profit = freight_only_price - freight_cost
      {
        'id' => card['id'],
        'name' => card['name'],
        'description' => card['description'],
        'base_tariff_per_km' => base_tariff.round(2),
        'final_tariff_per_km' => (base_tariff + adjustment).round(2),
        'freight_cost' => freight_cost.round(2),
        'initial_freight_price' => initial_freight_price.round(2),
        'freight_only_price' => freight_only_price.round(2),
        'services_cost' => services['total'],
        'final_price' => final_price.round(2),
        'profit' => profit.round(2),
        'real_margin_percent' => final_price.positive? ? (((final_price - freight_cost - services['total']) / final_price) * 100).round(2) : 0.0
      }
    end

    def service_costs
      parsed = @parsed_data.fetch('services', {}).to_h.stringify_keys
      helpers = @pricing.fetch('helpers', {}).to_h.stringify_keys
      assembly = @pricing.fetch('assembly', {}).to_h.stringify_keys
      helper_origin = integer(helpers['origin'], parsed.dig('helpers', 'origin'))
      helper_destination = integer(helpers['destination'], parsed.dig('helpers', 'destination'))
      disassembly_origin = integer(assembly['origin_disassembly'], parsed.dig('assembly', 'origin_disassembly'))
      destination_assembly = integer(assembly['destination_assembly'], parsed.dig('assembly', 'destination_assembly'))
      helper_unit = non_negative(@pricing['helper_unit'])
      assembler_unit = non_negative(@pricing['assembler_unit'])
      materials = @pricing['materials_selected'] ? non_negative(@pricing['materials_total']) : 0.0
      special = non_negative(@pricing['special_fee'])
      helper_total = (helper_origin + helper_destination) * helper_unit
      assembler_total = (disassembly_origin + destination_assembly) * assembler_unit
      {
        'helpers_origin' => helper_origin,
        'helpers_destination' => helper_destination,
        'disassembly_origin' => disassembly_origin,
        'assembly_destination' => destination_assembly,
        'helper_unit' => helper_unit.round(2),
        'assembler_unit' => assembler_unit.round(2),
        'materials' => materials.round(2),
        'special_fee' => special.round(2),
        'helpers_total' => helper_total.round(2),
        'assemblers_total' => assembler_total.round(2),
        'total' => (helper_total + assembler_total + materials + special).round(2)
      }
    end

    def integer(value, fallback)
      numeric = value.present? ? value.to_i : 0
      numeric.zero? && fallback.to_i.positive? ? [[fallback.to_i, 0].max, 999].min : [[numeric, 0].max, 999].min
    end

    def number(value, fallback = 0.0)
      value.present? ? Float(value) : fallback.to_f
    rescue ArgumentError, TypeError
      fallback.to_f
    end

    def non_negative(value)
      [number(value), 0.0].max
    end
  end
end
