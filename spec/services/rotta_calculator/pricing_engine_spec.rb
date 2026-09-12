require 'rails_helper'

RSpec.describe RottaCalculator::PricingEngine do
  let(:route) { { 'distance_km' => 100.0, 'duration_minutes' => 120 } }
  let(:parsed) do
    {
      'services' => {
        'helpers' => { 'origin' => 2, 'destination' => 1 },
        'assembly' => { 'origin_disassembly' => 1, 'destination_assembly' => 2 }
      }
    }
  end

  it 'builds six cards with the floor, services and truck multiplier' do
    result = described_class.new(
      route: route,
      parsed_data: parsed,
      pricing: {
        'helper_unit' => 100,
        'assembler_unit' => 200,
        'selected_card_id' => 'padrao',
        'margin_percent' => 35
      }
    ).call

    expect(result['cards'].length).to eq(6)
    expect(result['services']).to include(
      'helpers_total' => 300.0,
      'assemblers_total' => 600.0,
      'total' => 900.0
    )
    expect(result['selected']['freight_only_price']).to be >= 800.0
    expect(result['selected']['final_price']).to eq(result['selected']['freight_only_price'] + 900.0)
    expect(result['truck_duration_minutes']).to eq(150)
    expect(result['tolls']).to eq(0.0)
  end

  it 'applies the manual per-kilometre adjustment after the floor' do
    without_adjustment = described_class.new(route: route, parsed_data: parsed, pricing: {}).call['selected']['freight_only_price']
    with_adjustment = described_class.new(route: route, parsed_data: parsed, pricing: { 'adjustment_per_km' => 0.25 }).call['selected']['freight_only_price']

    expect(with_adjustment - without_adjustment).to eq(25.0)
  end
end
