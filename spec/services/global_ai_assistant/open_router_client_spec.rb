require 'rails_helper'

RSpec.describe GlobalAiAssistant::OpenRouterClient do
  subject(:client) { described_class.new(api_key: 'test-key', api_base: 'https://openrouter.ai/api/v1') }

  it 'sends the required model through the OpenRouter-compatible endpoint' do
    response = instance_double(HTTParty::Response, success?: true, parsed_response: {
      'choices' => [{ 'message' => { 'content' => 'OK' } }]
    })
    allow(HTTParty).to receive(:post).and_return(response)

    expect(client.call([{ role: 'user', content: 'teste' }])).to eq('OK')
    expect(HTTParty).to have_received(:post).with(
      'https://openrouter.ai/api/v1/chat/completions',
      hash_including(body: include('deepseek/deepseek-v4-flash-0731'))
    )
  end

  it 'raises a useful error when OpenRouter rejects the request' do
    response = instance_double(HTTParty::Response, success?: false, code: 401, parsed_response: {
      'error' => { 'message' => 'invalid key' }
    })
    allow(HTTParty).to receive(:post).and_return(response)

    expect { client.call([]) }.to raise_error(/OpenRouter respondeu HTTP 401: invalid key/)
  end

  it 'allows the profile flow to use a longer bounded timeout' do
    timed_client = described_class.new(
      api_key: 'test-key',
      api_base: 'https://openrouter.ai/api/v1',
      timeout: 50
    )
    response = instance_double(HTTParty::Response, success?: true, parsed_response: {
      'choices' => [{ 'message' => { 'content' => 'OK' } }]
    })
    allow(HTTParty).to receive(:post).and_return(response)

    timed_client.call([{ role: 'user', content: 'teste' }])

    expect(HTTParty).to have_received(:post).with(
      anything,
      hash_including(timeout: 50)
    )
  end
end
