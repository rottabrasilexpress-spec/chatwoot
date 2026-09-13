require 'rails_helper'

RSpec.describe RottaCalculator::InventoryResolver do
  it 'recomputes totals from the catalog and flags unknown items' do
    result = described_class.new.call([
      { 'name' => 'Cama', 'quantity' => 2, 'original_line' => '2 Cama' },
      { 'name' => 'Item sem catálogo', 'quantity' => 1, 'original_line' => 'Item sem catálogo' }
    ])

    expect(result['mounted_m3']).to eq(4.4)
    expect(result['disassembled_m3']).to eq(0.5)
    expect(result['weight_kg']).to eq(140.0)
    expect(result['manual_review']).to be(true)
  end

  it 'uses explicit dimensions for an unknown item while preserving manual review' do
    result = described_class.new.call([
      {
        'name' => 'Mesa especial',
        'quantity' => 2,
        'measured_m3' => 0.72,
        'dimensions_mm' => [1200.0, 800.0, 750.0],
        'original_line' => '[2] Mesa especial — 120 x 80 x 75 cm'
      }
    ])

    expect(result['mounted_m3']).to eq(1.44)
    expect(result['disassembled_m3']).to eq(1.44)
    expect(result['manual_review']).to be(true)
    expect(result.dig('items', 0)).to include('measured_m3' => 0.72, 'dimensions_mm' => [1200.0, 800.0, 750.0])
  end
end
