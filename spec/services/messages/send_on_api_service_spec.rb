require 'rails_helper'

RSpec.describe Messages::SendOnApiService do
  let(:api_channel) { create(:channel_api) }
  let(:contact_inbox) { create(:contact_inbox, inbox: api_channel.inbox, source_id: '5511965927865@s.whatsapp.net') }
  let(:conversation) { create(:conversation, inbox: api_channel.inbox, contact_inbox: contact_inbox) }
  let(:agent) { create(:user, account: conversation.account, name: 'Caio') }
  let(:message) { create(:message, message_type: :outgoing, content: 'Teste Uazapi', conversation: conversation, sender: agent) }

  before do
    environment = ENV.to_h
    environment.delete('ROTTABRASIL_HUMAN_LOCK_WEBHOOK_URL')
    environment.delete('ROTTABRASIL_HUMAN_LOCK_WEBHOOK_TOKEN')
    stub_const('ENV', environment.merge(
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
          'token' => 'test-token'
        },
        body: hash_including(
          'number' => '5511965927865',
          'text' => 'Teste Uazapi',
          'readchat' => true,
          'track_source' => 'chatwoot-human',
          'track_id' => "message-#{message.id}"
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
    expect(message.content_attributes).to include(
      'external_echo' => true,
      'rotta_uazapi' => true
    )
    expect(message.content_attributes).not_to have_key('rotta_uazapi_pending_echo')
    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text').with do |request|
      JSON.parse(request.body).fetch('text') == 'Teste Uazapi'
    end).to have_been_made
    expect(ENV).not_to include('ROTTABRASIL_HUMAN_LOCK_WEBHOOK_URL', 'ROTTABRASIL_HUMAN_LOCK_WEBHOOK_TOKEN')
  end

  it 'does not mark automated Chatwoot messages as human interventions' do
    allow(message).to receive(:sender_type).and_return('AgentBot')
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(body: hash_including('track_source' => 'chatwoot'))
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBAUTOMATED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(body: hash_including('track_source' => 'chatwoot-human'))).not_to have_been_made
  end

  it 'preserves WhatsApp formatting, emojis, blank lines and separators verbatim' do
    formatted_content = "ORÇAMENTO FINAL - ROTTA BRASIL EXPRESS\r\n\r\n💰 *OPÇÕES DE INVESTIMENTO*\r\n\r\n*Valor:* ✅ R$ 7.993,73\r\n\r\n---\r\n\r\n🌐 SITE: www.rottabrasilexpress.com.br"
    message.update!(content: formatted_content)

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with do |request|
        headers = request.headers.transform_keys(&:downcase)
        payload = JSON.parse(request.body)

        headers['convert'].blank? &&
          payload['text'] == formatted_content.gsub(/\r\n?/, "\n") &&
          payload['text'].include?('💰 *OPÇÕES DE INVESTIMENTO*') &&
          payload['text'].include?("\n\n---\n\n")
      end
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBFORMATTED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBFORMATTED123')
    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made
  end

  it 'uses the contact phone when WhatsApp identified the conversation with an LID' do
    contact_inbox.update!(source_id: '123456789012345@lid')
    conversation.contact.update!(phone_number: '+55 44 99736-6408')
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(body: hash_including('number' => '5544997366408'))
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBLIDFALLBACK123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBLIDFALLBACK123')
  end

  it 'uses the contact phone when an API contact inbox has Chatwoot internal UUID source id' do
    contact_inbox.update!(source_id: SecureRandom.uuid)
    conversation.contact.update!(phone_number: '+55 34 99141-6802')

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(body: hash_including('number' => '5534991416802'))
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBUUIDPHONE123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBUUIDPHONE123')
  end

  it 'never includes the agent name in WhatsApp message text, even when the legacy flag is enabled' do
    api_channel.update!(additional_attributes: {
      'rotta_include_agent_name_in_whatsapp' => true
    })

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .with(body: hash_including('text' => 'Teste Uazapi'))
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBNAMED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBNAMED123')
  end

  it 'sends a message only once when duplicate delivery jobs overlap' do
    request_started = Queue.new

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return do
        request_started << true
        sleep 0.2
        {
          status: 200,
          body: { 'key' => { 'id' => '3EBCONCURRENT123' } }.to_json,
          headers: { 'content-type' => 'application/json' }
        }
      end

    threads = 2.times.map do
      Thread.new do
        described_class.new(message: Message.find(message.id)).perform
      end
    end

    request_started.pop
    sleep 0.05
    threads.each(&:join)

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.once
    expect(message.reload.source_id).to eq('3EBCONCURRENT123')
  end

  it 'keeps a read-timeout unconfirmed instead of marking an accepted send as failed' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_raise(Net::ReadTimeout.new('response timed out'))

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('sent')
    expect(message.external_error).to be_blank
    expect(message.additional_attributes).to include('rotta_uazapi_confirmation_pending' => true)
  end

  it 'does not resend after an ambiguous timeout while delivery confirmation is pending' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_raise(Net::ReadTimeout.new('response timed out'))

    described_class.new(message: message).perform

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBRETRYBLOCKED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: Message.find(message.id)).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.once
    expect(message.reload.source_id).to be_blank
    expect(message.content_attributes).to include('rotta_uazapi_pending_echo' => true)
  end

  it 'does not release the send claim for an ambiguous connection failure' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_raise(Errno::ECONNRESET.new)

    described_class.new(message: message).perform

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBRESETBLOCKED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: Message.find(message.id)).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.once
    expect(message.reload.source_id).to be_blank
    expect(message.content_attributes).to include('rotta_uazapi_pending_echo' => true)
  end

  it 'allows a retry after a confirmed provider rejection' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(
        {
          status: 422,
          body: { 'message' => 'número inválido' }.to_json,
          headers: { 'content-type' => 'application/json' }
        },
        {
          status: 200,
          body: { 'key' => { 'id' => '3EBRETRYLEGIT123' } }.to_json,
          headers: { 'content-type' => 'application/json' }
        }
      )

    described_class.new(message: message).perform
    expect(message.reload.status).to eq('failed')

    described_class.new(message: Message.find(message.id)).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.twice
    expect(message.reload.source_id).to eq('3EBRETRYLEGIT123')
    expect(message.status).to eq('sent')
  end

  it 'sends an audio message only once when duplicate delivery jobs overlap' do
    attachment = message.attachments.build(account_id: message.account_id, file_type: :audio)
    attachment.file.attach(
      io: StringIO.new('audio bytes'),
      filename: 'voice.ogg',
      content_type: 'audio/ogg'
    )
    attachment.save!
    allow(attachment).to receive(:download_url).and_return('https://chatwoot.example/voice.ogg')
    request_started = Queue.new

    stub_request(:post, 'https://transportadoras.uazapi.com/send/media')
      .to_return do
        request_started << true
        sleep 0.2
        {
          status: 200,
          body: { 'key' => { 'id' => '3EBAUDIOCONCURRENT123' } }.to_json,
          headers: { 'content-type' => 'application/json' }
        }
      end

    threads = 2.times.map do
      Thread.new do
        described_class.new(message: Message.find(message.id)).perform
      end
    end

    request_started.pop
    sleep 0.05
    threads.each(&:join)

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/media')).to have_been_made.once
    expect(message.reload.source_id).to eq('3EBAUDIOCONCURRENT123')
  end

  it 'keeps the claim when persistence fails after an accepted response' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBPERSISTENCEBLOCKED123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )
    allow(message).to receive(:update!).and_wrap_original do |original, *args, **kwargs, &block|
      attributes = args.first || kwargs
      if attributes[:source_id].present? || attributes['source_id'].present?
        raise EOFError, 'connection closed while persisting provider id'
      end

      original.call(*args, **kwargs, &block)
    end

    described_class.new(message: message).perform

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(status: 200, body: { 'key' => { 'id' => '3EBDUPLICATEBLOCKED123' } }.to_json)
    described_class.new(message: Message.find(message.id)).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.once
    expect(message.reload.source_id).to be_blank
    expect(message.content_attributes).to include('rotta_uazapi_pending_echo' => true)
  end

  it 'marks the message as failed when Uazapi rejects the request' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(status: 422, body: { 'message' => 'número inválido' }.to_json)

    described_class.new(message: message).perform

    expect(message.reload.status).to eq('failed')
    expect(message.external_error).to include('HTTP 422')
  end

  it 'sends a recorded audio attachment as a WhatsApp voice message' do
    attachment = message.attachments.build(account_id: message.account_id, file_type: :audio)
    attachment.file.attach(
      io: StringIO.new('audio bytes'),
      filename: 'voice.ogg',
      content_type: 'audio/ogg'
    )
    attachment.save!
    allow(attachment).to receive(:download_url).and_return('https://chatwoot.example/voice.ogg')

    stub_request(:post, 'https://transportadoras.uazapi.com/send/media')
      .with(
        body: hash_including(
          'number' => '5511965927865',
          'type' => 'ptt',
          'file' => 'https://chatwoot.example/voice.ogg',
          'track_source' => 'chatwoot-human',
          'track_id' => "message-#{message.id}"
        )
      )
      .to_return(
        status: 200,
        body: { 'key' => { 'id' => '3EBVOICE123' } }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('3EBVOICE123')
    expect(message.status).to eq('sent')
  end
end
