module RottaCalculator
  class OperationalAudit
    MOUNTED_MARGIN_PERCENT = 12.0
    DISASSEMBLED_MARGIN_PERCENT = 20.0
    DRIVER_RATE_PER_KM = 2.0
    VEHICLE_REFERENCES = [
      { 'label' => 'Van / Kombi', 'capacity_m3' => 10.0 },
      { 'label' => 'HR / Bongo / Utilitário', 'capacity_m3' => 14.0 },
      { 'label' => 'VUC / Caminhão leve', 'capacity_m3' => 20.0 },
      { 'label' => 'Caminhão 3/4', 'capacity_m3' => 30.0 }
    ].freeze

    def self.inventory(inventory)
      inventory = inventory.to_h.stringify_keys
      mounted_base = number(inventory['mounted_m3'])
      disassembled_base = number(inventory['disassembled_m3'])
      mounted = load_summary(mounted_base, MOUNTED_MARGIN_PERCENT)
      disassembled = load_summary(disassembled_base, DISASSEMBLED_MARGIN_PERCENT)

      {
        'mounted' => mounted,
        'disassembled' => disassembled,
        'weight_kg' => number(inventory['weight_kg']).round(2),
        'uses_cubed_weight' => false
      }
    end

    def self.financial(route:, pricing:)
      route = route.to_h.stringify_keys
      pricing = pricing.to_h.stringify_keys
      selected = pricing.fetch('selected', {}).to_h.stringify_keys
      services = pricing.fetch('services', {}).to_h.stringify_keys
      services_total = number(services['total'])
      freight_only = number(selected['freight_only_price'])
      distance = number(route['distance_km'])

      {
        'driver_payout' => (distance * DRIVER_RATE_PER_KM).round(2),
        'driver_rate_per_km' => DRIVER_RATE_PER_KM,
        'services' => services_total.round(2),
        'price_without_services' => freight_only.round(2),
        'services_with_half' => (freight_only + (services_total * 0.5)).round(2),
        'final_price' => number(selected['final_price']).round(2),
        'route_duration_minutes' => number(route['duration_minutes']).round,
        'truck_duration_minutes' => number(pricing['truck_duration_minutes']).round
      }
    end

    def self.load_summary(base_m3, margin_percent)
      audited = (base_m3 * (1 + (margin_percent / 100))).round(3)
      vehicle = VEHICLE_REFERENCES.find { |reference| audited <= reference['capacity_m3'] } || VEHICLE_REFERENCES.last

      {
        'base_m3' => base_m3.round(3),
        'audited_m3' => audited,
        'margin_percent' => margin_percent,
        'vehicle' => vehicle['label'],
        'capacity_m3' => vehicle['capacity_m3'],
        'usage_percent' => ((audited / vehicle['capacity_m3']) * 100).round
      }
    end
    private_class_method :load_summary

    def self.number(value)
      Float(value || 0)
    rescue ArgumentError, TypeError
      0.0
    end
    private_class_method :number
  end
end
