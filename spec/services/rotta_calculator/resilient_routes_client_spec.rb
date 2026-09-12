require 'rails_helper'

RSpec.describe RottaCalculator::ResilientRoutesClient do
  it 'uses the OSM/OSRM fallback when Google is unavailable and keeps tolls disabled' do
    primary = double('primary')
    fallback = double('fallback')
    allow(primary).to receive(:call).and_raise(RottaCalculator::UpstreamError, 'Google indisponível')
    allow(fallback).to receive(:call).and_return('distance_km' => 10.0, 'duration_minutes' => 20)

    result = described_class.new(primary: primary, fallback: fallback).call(origin: 'A', destination: 'B')

    expect(result).to include('distance_km' => 10.0, 'toll_status' => 'disabled', 'provider' => 'osm-osrm-fallback')
  end
end
