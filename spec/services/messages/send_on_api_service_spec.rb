require 'rails_helper'

RSpec.describe Messages::SendOnApiService do
  let(:api_channel) { create(:channel_api) }
  let(:contact_inbox) { create(:contact_inbox, inbox: api_channel.inbox, source_id: '5511965927865@s.whatsapp.net') }
  let(:conversation) { create(:conversation, inbox: api_channel.inbox, contact_inbox: contact_inbox) }
  let(:message) { create(:message, message_type: :outgoing, content: 'Teste Uazapi', conversation: conversation) }

  before do
    stub_const('ENV', ENV.to_h.merge(
                       'ROTTABRASIL_UAZAPI_BASE_URL' => 'https://transportadoras.uazapi.com',
                       'ROTTABRASIL_UAZAPI_TOKEN' => 'test-token'
                     ))
  end

  it 'sends text through Uazapi and stores the provider message id' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'convert' => 'true',
          'token' => 'test-token'
        },
        body: hash_including(
          'number' => '5511965927865',
          'text' => 'Teste Uazapi',
          'readchat' => true
        )
      )
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBTESTE123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBTESTE123')
    expect(message.status).to eq('sent')
  end

  it 'marks the message as failed when Uazapi rejects the request' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(status: 422, body: { 'message' => 'número inválido' }.to_json)

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to include('HTTP 422')
  end
end
