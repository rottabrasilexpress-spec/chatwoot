require 'rails_helper'

RSpec.describe RottaCalculator::GoogleRoutesClient do
  let(:response) { double('response', success?: true, code: 200, parsed_response: { 'routes' => [{ 'distanceMeters' => 12345, 'duration' => '3661s' }] }) }
  let(:http_client) { double('http_client') }

  before do
    allow(http_client).to receive(:post).and_return(response)
    allow(ENV).to receive(:[]).with('GOOGLE_ROUTES_API_KEY').and_return('routes-test-key')
  end

  it 'requests distance and duration without enabling toll computation' do
    result = described_class.new(http_client: http_client).call(origin: 'São Paulo - SP', destination: 'Salvador - BA')

    expect(result).to eq('distance_km' => 12.3, 'duration_minutes' => 62)
    expect(http_client).to have_received(:post) do |_url, options|
      body = JSON.parse(options[:body])
      expect(body).not_to have_key('extraComputations')
      expect(body).not_to have_key('routeModifiers')
      expect(options[:headers]['X-Goog-FieldMask']).not_to include('toll')
    end
  end
end
