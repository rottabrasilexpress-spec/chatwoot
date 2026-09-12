require 'rails_helper'

RSpec.describe RottaCalculator::PreBudgetParser do
  let(:text) do
    <<~TEXT
      Cliente: Antonio
      Data pretendida: 3 a 5 de outubro
      Origem: Palotina - PR
      Destino: Linhares - ES
      INVENTÁRIO:
      2x Sofá retrátil com chaise
      1 Cama
      3 caixas pequenas
      Desmontagem: sim, cama
      Montagem: a confirmar
    TEXT
  end

  it 'extracts factual fields, resolves catalog names and keeps a snapshot hash' do
    result = described_class.new(reading_text: text, freight: {}, inventory: {}, services: {}).call

    expect(result).to include(
      'client_name' => 'Antonio',
      'date' => '3 a 5 de outubro',
      'origin' => 'Palotina - PR',
      'destination' => 'Linhares - ES',
      'snapshot_algorithm' => 'sha256'
    )
    expect(result['snapshot_hash']).to match(/\A[0-9a-f]{64}\z/)
    expect(result.dig('inventory', 'item_count')).to eq(6)
    expect(result.dig('inventory', 'items', 0)).to include('quantity' => 2, 'catalog_name' => 'Sofá retrátil com chaise')
    expect(result.dig('services', 'assembly', 'requested')).to be(true)
    expect(result.dig('services', 'assembly', 'destination_assembly')).to eq(0)
  end

  it 'rejects oversized input before calling integrations' do
    expect {
      described_class.new(reading_text: (['linha'] * 301).join("\n"), freight: {}, inventory: {}, services: {}).call
    }.to raise_error(ArgumentError, /300 linhas/)
  end
end
