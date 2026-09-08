require 'rails_helper'

RSpec.describe Messages::UazapiActionService do
  let(:api_channel) { create(:channel_api) }
  let(:contact_inbox) do
    create(:contact_inbox, inbox: api_channel.inbox, source_id: '5511965927865@s.whatsapp.net')
  end
  let(:conversation) { create(:conversation, inbox: api_channel.inbox, contact_inbox: contact_inbox) }
  let(:message) do
    create(
      :message,
      message_type: :outgoing,
      content: 'Mensagem original',
      source_id: '3EBTESTE123',
      conversation: conversation
    )
  end

  before do
    stub_const('ENV', ENV.to_h.merge(
                       'ROTTABRASIL_UAZAPI_BASE_URL' => 'https://transportadoras.uazapi.com',
                       'ROTTABRASIL_UAZAPI_TOKEN' => 'test-token'
                     ))
  end

  it 'edits a message and sends the provider message id' do
    stub_request(:post, 'https://transportadoras.uazapi.com/message/edit')
      .with(
        headers: { 'token' => 'test-token' },
        body: { 'id' => '3EBTESTE123', 'text' => 'Mensagem corrigida' }
      )
      .to_return(status: 200, body: { id: '3EBTESTE123' }.to_json)

    response = described_class.new(message: message, action: :edit, text: 'Mensagem corrigida').perform

    expect(response['id']).to eq('3EBTESTE123')
  end

  it 'sends a reaction to the WhatsApp chat' do
    stub_request(:post, 'https://transportadoras.uazapi.com/message/react')
      .with(
        headers: { 'token' => 'test-token' },
        body: {
          'number' => '5511965927865',
          'text' => '👍',
          'id' => '3EBTESTE123'
        }
      )
      .to_return(status: 200, body: { success: true }.to_json)

    expect(described_class.new(message: message, action: :react, emoji: '👍').perform['success']).to be(true)
  end

  it 'pins a message for the configured duration' do
    stub_request(:post, 'https://transportadoras.uazapi.com/message/pin')
      .with(
        headers: { 'token' => 'test-token' },
        body: { 'id' => '3EBTESTE123', 'pin' => true, 'duration' => 7 }
      )
      .to_return(status: 200, body: { success: true }.to_json)

    expect(
      described_class.new(message: message, action: :pin, pin: true, duration: 7).perform['success']
    ).to be(true)
  end

  it 'fails safely when the message has no provider id' do
    message.update!(source_id: nil)

    expect {
      described_class.new(message: message, action: :react, emoji: '❤️').perform
    }.to raise_error(Messages::UazapiActionService::ProviderError, /ID externo/)
  end
end
