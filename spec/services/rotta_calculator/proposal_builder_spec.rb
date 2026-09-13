require 'rails_helper'

RSpec.describe RottaCalculator::ProposalBuilder do
  let(:freight) { { 'client_name' => 'Edson', 'date' => '3 a 5 de outubro', 'origin' => 'A - SP', 'destination' => 'B - SP' } }
  let(:route) { { 'distance_km' => 100.0 } }
  let(:inventory) { { 'mounted_m3' => 2.0, 'disassembled_m3' => 1.0 } }

  it 'shows one transport price when there are no services' do
    proposal = described_class.call(
      freight: freight,
      route: route,
      inventory: inventory,
      pricing: {
        'selected' => { 'final_price' => 800.0, 'freight_only_price' => 800.0 },
        'services' => { 'total' => 0.0 }
      }
    )

    expect(proposal).to include('Valor do transporte: R$ 800.00')
    expect(proposal).not_to include('Opção 2')
  end

  it 'uses half of services in the transport-only option' do
    proposal = described_class.call(
      freight: freight,
      route: route,
      inventory: inventory,
      pricing: {
        'selected' => { 'final_price' => 1200.0, 'freight_only_price' => 1000.0 },
        'services' => { 'total' => 200.0, 'helpers_origin' => 1 }
      }
    )

    expect(proposal).to include('Opção 1 — Transporte + serviços', 'Opção 2 — Somente transporte (serviços por conta do cliente)')
    expect(proposal).to include('Valor: R$ 1200.00', 'Valor: R$ 1100.00')
  end
end
