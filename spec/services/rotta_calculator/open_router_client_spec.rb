require 'rails_helper'

RSpec.describe RottaCalculator::OpenRouterClient do
  let(:response) do
    double(
      'response',
      success?: true,
      code: 200,
      parsed_response: {
        'choices' => [{ 'message' => { 'content' => '{"proposal":"ok","price":null}' } }]
      }
    )
  end
  let(:http_client) { double('http_client') }

  before do
    allow(http_client).to receive(:post).and_return(response)
    allow(ENV).to receive(:[]).with('OPENROUTER_API_KEY').and_return('openrouter-test-key')
    allow(ENV).to receive(:[]).with('OPENROUTER_MODEL').and_return('deepseek/deepseek-v4-flash-0731')
    allow(ENV).to receive(:fetch).with('FRONTEND_URL', 'https://atendimento.via-cargo.com').and_return('https://atendimento.via-cargo.com')
  end

  it 'uses the approved DeepSeek model and declares toll computation disabled' do
    result = described_class.new(http_client: http_client).call('route' => { 'distance_km' => 12.3 })

    expect(result).to include('proposal' => 'ok', 'price' => nil)
    expect(http_client).to have_received(:post) do |_url, options|
      body = JSON.parse(options[:body])
      expect(body['model']).to eq('deepseek/deepseek-v4-flash-0731')
      expect(body['messages'].first['content']).to include('permanentemente desativado')
      expect(body['messages'].last['content']).not_to include('tollAmount')
    end
  end
end
