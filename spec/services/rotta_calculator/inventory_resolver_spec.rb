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
end
