require 'rails_helper'

RSpec.describe RottaCalculator::OsrmRoutesClient do
  let(:geocoder) { double('geocoder') }
  let(:response) do
    double(
      'response',
      body: { 'routes' => [{ 'distance' => 12345, 'duration' => 3661, 'geometry' => 'encoded-route' }] }.to_json,
      code: 200
    )
  end

  before do
    allow(geocoder).to receive(:call).with('A').and_return('longitude' => -46.6, 'latitude' => -23.5)
    allow(geocoder).to receive(:call).with('B').and_return('longitude' => -38.5, 'latitude' => -12.9)
    allow(Net::HTTP).to receive(:get_response).and_return(response)
  end

  it 'returns an encoded polyline for the map fallback without tolls' do
    result = described_class.new(geocoder: geocoder).call(origin: 'A', destination: 'B')

    expect(result).to include(
      'distance_km' => 12.3,
      'duration_minutes' => 62,
      'polyline' => 'encoded-route',
      'toll_status' => 'disabled'
    )
  end
end
