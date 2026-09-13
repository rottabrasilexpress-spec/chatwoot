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

  it 'parses bracket quantities from the real pre-budget format and does not infer materials from boxes' do
    result = described_class.new(
      reading_text: <<~TEXT,
        Cliente: Edson
        Data: 3 a 5 de outubro
        Origem: Palotina-PR
        Destino: Linhares-ES
        📦 INVENTÁRIO
        - [1] Mesa com 6 cadeiras
        - [3] Cama box casal
        - [7] Caixas
        👷 EQUIPE (AJUDANTES)
        Carga (origem): 2 ajudantes
        Descarga (destino): 2 ajudantes
        🔧 SERVIÇOS
        Desmontagem: ❌ NÃO
        Montagem: ❌ NÃO
      TEXT
      freight: {}, inventory: {}, services: {}
    ).call

    expect(result.dig('inventory', 'items')).to include(
      include('quantity' => 1, 'name' => 'Mesa com 6 cadeiras'),
      include('quantity' => 3, 'name' => 'Cama box casal'),
      include('quantity' => 7, 'name' => 'Caixas')
    )
    expect(result.dig('services', 'helpers')).to eq('origin' => 2, 'destination' => 2)
    expect(result.dig('services', 'materials', 'selected')).to be(false)
  end

  it 'counts only structural catalog items when all furniture is requested' do
    result = described_class.new(
      reading_text: <<~TEXT,
        Origem: A - SP
        Destino: B - SP
        INVENTÁRIO
        [2] Cama box casal
        [1] TV 55 polegadas
        [1] Sofá 2 lugares
        [1] Guarda-roupa
        SERVIÇOS
        Desmontagem: sim, todos os móveis
      TEXT
      freight: {}, inventory: {}, services: {}
    ).call

    expect(result.dig('services', 'assembly', 'origin_disassembly')).to eq(3)
    expect(result.dig('services', 'assembly', 'manual_review')).to be(false)
  end

  it 'validates and stores explicit dimensions in millimetres' do
    result = described_class.new(
      reading_text: "Origem: A - SP\nDestino: B - SP\nINVENTÁRIO\n[2] Mesa especial — 120 x 80 x 75 cm",
      freight: {}, inventory: {}, services: {}
    ).call

    item = result.dig('inventory', 'items', 0)
    expect(item).to include('name' => 'Mesa especial', 'quantity' => 2, 'dimensions_mm' => [1200.0, 800.0, 750.0])
    expect(item['measured_m3']).to eq(0.72)
  end
end
