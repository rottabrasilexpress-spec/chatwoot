require 'rails_helper'

RSpec.describe RottaCalculator::InventoryCatalog do
  it 'does not map a specific unknown description to a generic shorter item' do
    expect(described_class.find('Mesa com 6 cadeiras')).to be_nil
    expect(described_class.find('Televisores 55"')).to be_nil
  end

  it 'keeps exact catalog names and aliases resolvable' do
    expect(described_class.find('Cama box casal').name).to eq('Cama box casal')
    expect(described_class.find('Caixas').name).to eq('Caixas/Sacos grandes')
  end
end
