require 'rails_helper'

RSpec.describe Messages::SendOnApiService do
  let(:api_channel) { create(:channel_api) }
  let(:contact_inbox) { create(:contact_inbox, inbox: api_channel.inbox, source_id: '5511965927865@s.whatsapp.net') }
  let(:conversation) { create(:conversation, inbox: api_channel.inbox, contact_inbox: contact_inbox) }
  let(:agent) { create(:user, account: conversation.account, name: 'Caio') }
  let(:message) { create(:message, message_type: :outgoing, content: 'Teste Uazapi', conversation: conversation, sender: agent) }

  before do
    stub_const('ENV', ENV.to_h.merge(
                       'ROTTABRASIL_UAZAPI_BASE_URL' => 'https://transportadoras.uazapi.com',
                       'ROTTABRASIL_UAZAPI_TOKEN' => 'test-token'
                     ))
  end

  around do |example|
    example.run
  ensure
    if example.metadata[:use_transactional_fixtures] == false
      Attachment.where(message_id: message.id).delete_all
      Message.where(id: message.id).delete_all
    end
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
    expect(message.content_attributes).to include(
      'external_echo' => true,
      'rotta_uazapi' => true
    )
    expect(message.content_attributes).not_to have_key('rotta_uazapi_pending_echo')
    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text').with do |request|
      JSON.parse(request.body).fetch('text') == 'Teste Uazapi'
    end).to have_been_made
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

  it 'sends a message only once when duplicate delivery jobs overlap', use_transactional_fixtures: false do
    request_started = Queue.new
    release_request = Queue.new

    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return do
        request_started << true
        release_request.pop(timeout: 5)
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

    expect(request_started.pop(timeout: 5)).to be(true)
    release_request << true
    threads.each(&:value)

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

  it 'does not resend after an ambiguous 503 response' do
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(
        {
          status: 503,
          body: { 'message' => 'temporarily unavailable' }.to_json,
          headers: { 'content-type' => 'application/json' }
        },
        {
          status: 200,
          body: { 'key' => { 'id' => '3EB503BLOCKED123' } }.to_json,
          headers: { 'content-type' => 'application/json' }
        }
      )

    described_class.new(message: message).perform
    described_class.new(message: Message.find(message.id)).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).to have_been_made.once
    expect(message.reload.source_id).to be_blank
    expect(message.content_attributes).to include('rotta_uazapi_pending_echo' => true)
  end

  it 'fails closed when a stale claim has an inconsistent track id' do
    message.update!(
      content_attributes: {
        'rotta_uazapi_pending_echo' => true,
        'uazapi_track_id' => 'message-from-another-claim'
      }
    )
    stub_request(:post, 'https://transportadoras.uazapi.com/send/text')
      .to_return(status: 200, body: { 'key' => { 'id' => '3EBINCONSISTENTBLOCKED123' } }.to_json)

    described_class.new(message: message).perform

    expect(a_request(:post, 'https://transportadoras.uazapi.com/send/text')).not_to have_been_made
    expect(message.reload.content_attributes).to include(
      'rotta_uazapi_pending_echo' => true,
      'uazapi_track_id' => 'message-from-another-claim'
    )
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

  it 'sends an audio message only once when duplicate delivery jobs overlap', use_transactional_fixtures: false do
    attachment = message.attachments.build(account_id: message.account_id, file_type: :audio)
    attachment.file.attach(
      io: StringIO.new('audio bytes'),
      filename: 'voice.ogg',
      content_type: 'audio/ogg'
    )
    attachment.save!
    allow(attachment).to receive(:download_url).and_return('https://chatwoot.example/voice.ogg')
    request_started = Queue.new
    release_request = Queue.new

    stub_request(:post, 'https://transportadoras.uazapi.com/send/media')
      .to_return do
        request_started << true
        release_request.pop(timeout: 5)
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

    expect(request_started.pop(timeout: 5)).to be(true)
    release_request << true
    threads.each(&:value)

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
          'track_source' => 'chatwoot'
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

  describe 'maintenance tasks' do
    let(:stale_message) do
      create(
        :message,
        message_type: :outgoing,
        content: 'Claim pendente',
        conversation: conversation,
        sender: agent,
        content_attributes: {
          'rotta_uazapi_pending_echo' => true,
          'rotta_uazapi_claimed_at' => 2.hours.ago.iso8601
        },
        additional_attributes: { 'rotta_uazapi_confirmation_pending' => true }
      ).tap do |record|
        record.update!(
          content_attributes: record.content_attributes.merge('uazapi_track_id' => "message-#{record.id}")
        )
      end
    end

    after do
      Rake::Task['rotta_uazapi:report_stale_pending_sends'].reenable
      Rake::Task['rotta_uazapi:release_pending_send'].reenable
      ENV.delete('MESSAGE_ID')
      ENV.delete('CONFIRM')
    end

    it 'reports stale claims without releasing or resending them' do
      expect do
        Rake::Task['rotta_uazapi:report_stale_pending_sends'].invoke
      end.to output(/"message_id": #{stale_message.id}/).to_stdout

      expect(stale_message.reload.content_attributes).to include('rotta_uazapi_pending_echo' => true)
    end

    it 'releases only the explicitly confirmed stale message' do
      ENV['MESSAGE_ID'] = stale_message.id.to_s
      ENV['CONFIRM'] = 'I_UNDERSTAND'

      expect do
        Rake::Task['rotta_uazapi:release_pending_send'].invoke
      end.to output(/Claim UAZAPI liberado.*Nenhum reenvio/m).to_stdout

      expect(stale_message.reload.content_attributes).not_to have_key('rotta_uazapi_pending_echo')
      expect(stale_message.content_attributes).not_to have_key('rotta_uazapi_claimed_at')
      expect(stale_message.additional_attributes).not_to have_key('rotta_uazapi_confirmation_pending')
    end

    it 'does not release an inconsistent claim' do
      stale_message.update!(
        content_attributes: stale_message.content_attributes.merge('uazapi_track_id' => 'message-from-another-claim')
      )
      ENV['MESSAGE_ID'] = stale_message.id.to_s
      ENV['CONFIRM'] = 'I_UNDERSTAND'

      expect do
        Rake::Task['rotta_uazapi:release_pending_send'].invoke
      end.to raise_error(SystemExit, /track_id do claim é inconsistente/)

      expect(stale_message.reload.content_attributes).to include(
        'rotta_uazapi_pending_echo' => true,
        'uazapi_track_id' => 'message-from-another-claim'
      )
    end
  end
end
