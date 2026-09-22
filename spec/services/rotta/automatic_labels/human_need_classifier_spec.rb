require 'rails_helper'

RSpec.describe Rotta::AutomaticLabels::HumanNeedClassifier do
  it 'sends the fixed DeepSeek model with a bounded context and token budget' do
    response = double(success?: true, code: 200, parsed_response: {
      'choices' => [{ 'message' => { 'content' => '{"needs_human":true,"confidence":0.91,"reason":"pedido claro"}' } }]
    })
    http_client = double
    request = nil
    allow(http_client).to receive(:post) do |*arguments|
      request = arguments
      response
    end

    decision = described_class.new(http_client:, api_key: 'test-key').call(
      last_message: 'x' * 900,
      recent_messages: Array.new(6) { |index| { role: 'cliente', content: "mensagem #{index} #{'y' * 900}" } }
    )

    body = JSON.parse(request[1][:body])
    expect(request[0]).to eq(described_class::ENDPOINT)
    expect(body['model']).to eq('deepseek/deepseek-v4-flash-0731')
    expect(body['max_tokens']).to eq(120)
    expect(body['messages'][1]['content'].bytesize).to be < 4_000
    expect(decision).to have_attributes(needs_human: true, confidence: 0.91)
  end

  it 'fails closed when the model does not return valid JSON' do
    response = double(success?: true, code: 200, parsed_response: {
      'choices' => [{ 'message' => { 'content' => 'não sei' } }]
    })
    http_client = double
    allow(http_client).to receive(:post).and_return(response)

    expect {
      described_class.new(http_client:, api_key: 'test-key').call(last_message: 'valor')
    }.to raise_error(Rotta::AutomaticLabels::HumanNeedClassifier::Error)
  end
end
