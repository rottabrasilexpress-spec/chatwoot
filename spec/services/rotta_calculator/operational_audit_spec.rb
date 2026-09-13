require 'rails_helper'

RSpec.describe RottaCalculator::OperationalAudit do
  it 'matches the Hub volume margins and vehicle thresholds' do
    result = described_class.inventory(
      'mounted_m3' => 10.22,
      'disassembled_m3' => 6.22,
      'weight_kg' => 561
    )

    expect(result).to include(
      'mounted' => include(
        'base_m3' => 10.22,
        'audited_m3' => 11.446,
        'margin_percent' => 12.0,
        'vehicle' => 'HR / Bongo / Utilitário',
        'capacity_m3' => 14.0,
        'usage_percent' => 82
      ),
      'disassembled' => include(
        'base_m3' => 6.22,
        'audited_m3' => 7.464,
        'margin_percent' => 20.0,
        'vehicle' => 'Van / Kombi',
        'capacity_m3' => 10.0,
        'usage_percent' => 75
      ),
      'weight_kg' => 561.0,
      'uses_cubed_weight' => false
    )
  end

  it 'separates driver payout, services and the half-service option' do
    detail = described_class.financial(
      route: { 'distance_km' => 2760.7, 'duration_minutes' => 2135 },
      pricing: {
        'truck_duration_minutes' => 2669,
        'services' => { 'total' => 1700 },
        'selected' => { 'freight_only_price' => 8494.37, 'final_price' => 10194.37 }
      }
    )

    expect(detail).to include(
      'driver_payout' => 5521.4,
      'services' => 1700.0,
      'price_without_services' => 8494.37,
      'services_with_half' => 9344.37,
      'final_price' => 10194.37,
      'route_duration_minutes' => 2135,
      'truck_duration_minutes' => 2669
    )
  end
end
