require 'rails_helper'

RSpec.describe RottaCalculator::CalculateService do
  let(:routes_client) { double('routes_client', call: { 'distance_km' => 12.3, 'duration_minutes' => 62 }) }
  let(:ai_client) { double('ai_client') }

  it 'passes factual calculator context to the AI and keeps tolls disabled' do
    allow(ai_client).to receive(:call).and_return(
      'proposal' => 'Proposta baseada nos dados informados.',
      'summary' => 'Resumo factual.',
      'missing_information' => [],
      'extracted_data' => {},
      'price' => nil,
      'pricing_note' => 'Tabela ausente.'
    )

    result = described_class.new(
      {
        'reading_text' => 'Cliente informou origem e destino.',
        'freight' => { 'origin' => 'São Paulo - SP', 'destination' => 'Salvador - BA' },
        'services' => [{ 'label' => 'Montador', 'selected' => true }],
        'inventory' => { 'item_count' => 1, 'volume_m3' => 0.2 }
      },
      routes_client: routes_client,
      ai_client: ai_client
    ).call

    expect(result).to include(
      'api_status' => 'complete',
      'ai_status' => 'complete',
      'toll_status' => 'disabled',
      'price' => 627.68
    )
    expect(result['pricing']['cards'].length).to eq(6)
    expect(result['proposal']).to include('Valor do transporte: R$ 627.68', 'Validade: 7 dias')
    expect(result['proposal']).not_to include('Opção 2')
    expect(ai_client).to have_received(:call) do |context|
      expect(context['toll']).to eq('enabled' => false, 'calculated' => false)
      expect(context['route']).to include(
        'origin' => 'São Paulo - SP',
        'destination' => 'Salvador - BA',
        'toll_status' => 'disabled'
      )
      expect(context['route']).not_to have_key('polyline')
      expect(context.to_json).not_to include('pedágio', 'tollAmount', 'extraComputations')
    end
  end

  it 'uses origin and destination parsed from the pasted reading when fields are blank' do
    allow(routes_client).to receive(:call).with(
      origin: 'Palotina - PR',
      destination: 'Linhares - ES'
    ).and_return('distance_km' => 100, 'duration_minutes' => 120)
    allow(ai_client).to receive(:call).and_return(
      'summary' => 'Resumo factual.',
      'missing_information' => [],
      'extracted_data' => {},
      'price' => nil
    )

    result = described_class.new(
      {
        'reading_text' => "Origem: Palotina - PR\nDestino: Linhares - ES\n1 Cama",
        'freight' => {},
        'inventory' => {}
      },
      routes_client: routes_client,
      ai_client: ai_client
    ).call

    expect(result['route']).to eq('Palotina - PR → Linhares - ES')
    expect(routes_client).to have_received(:call).with(
      origin: 'Palotina - PR',
      destination: 'Linhares - ES'
    )
  end

  it 'keeps the route response available when the AI provider is slow' do
    allow(ai_client).to receive(:call) do
      sleep 0.05
      { 'summary' => 'Resposta lenta.' }
    end

    result = described_class.new(
      {
        'reading_text' => 'Origem: São Paulo - SP\nDestino: Salvador - BA',
        'freight' => { 'origin' => 'São Paulo - SP', 'destination' => 'Salvador - BA' },
        'inventory' => {}
      },
      routes_client: routes_client,
      ai_client: ai_client,
      ai_timeout: 0.01
    ).call

    expect(result).to include('route' => 'São Paulo - SP → Salvador - BA', 'ai_status' => 'degraded')
  end
end
