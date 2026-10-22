# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RottaUazapiHistoryReconciliationJob, type: :job do
  subject(:perform_job) { described_class.perform_now }

  before do
    stub_const('RottaUazapiHistoryReconciliationJob::BASE_URL', 'https://uazapi.test')
    stub_const('RottaUazapiHistoryReconciliationJob::CHATWOOT_INTERNAL_URL', 'http://rails:3000')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('ROTTABRASIL_UAZAPI_TOKEN').and_return('instance-token')
    allow(ENV).to receive(:[]).with('ROTTABRASIL_UAZAPI_INSTANCE_TOKEN').and_return(nil)
    allow(ENV).to receive(:[]).with('ROTTABRASIL_UAZAPI_WEBHOOK_TOKEN').and_return('webhook-token')
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:get).and_return(nil)
    allow(Redis::Alfred).to receive(:delete)
    allow(Redis::Alfred).to receive(:delete_if_equals)
    stub_const('RottaUazapiHistoryReconciliationJob::ACCOUNT_ID', create(:account).id)

    stub_request(:post, 'https://uazapi.test/chat/find').to_return(
      status: 200,
      body: { chats: [{ wa_chatid: '5511999999999@s.whatsapp.net', wa_lastMsgTimestamp: Time.current.to_i }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, 'https://uazapi.test/message/find').to_return(
      status: 200,
      body: {
        messages: [
          { id: '5511000000000:incoming-1', messageid: 'incoming-1', chatid: '5511999999999@s.whatsapp.net', fromMe: false, text: 'Olá', timestamp: Time.current.to_i },
          { messageid: 'outgoing-1', chatid: '5511999999999@s.whatsapp.net', fromMe: true, text: 'Resposta', timestamp: Time.current.to_i }
        ]
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history').to_return(
      status: 200,
      body: { ok: true }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'replays recent incoming and outgoing messages through the idempotent webhook path' do
    perform_job

    %w[incoming-1 outgoing-1].each do |message_id|
      expect(
        a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')
          .with(headers: { 'X-Forwarded-Proto' => 'https' })
          .with { |request| JSON.parse(request.body).dig('data', 'messageid') == message_id }
      ).to have_been_made.once
    end
  end

  it 'does not overlap reconciliation runs' do
    allow(Redis::Alfred).to receive(:set).and_return(false)

    perform_job

    expect(a_request(:post, 'https://uazapi.test/chat/find')).not_to have_been_made
  end

  it 'does not replay an existing message, but still recovers the missing outgoing message' do
    conversation = create(:conversation, account_id: described_class::ACCOUNT_ID)
    create(:message, conversation: conversation, account_id: described_class::ACCOUNT_ID, source_id: 'incoming-1')

    perform_job

    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')
      .with { |request| JSON.parse(request.body).dig('data', 'messageid') == 'incoming-1' }).not_to have_been_made
    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')
      .with { |request| JSON.parse(request.body).dig('data', 'messageid') == 'outgoing-1' }).to have_been_made.once
  end

  it 'only releases the reconciliation lock owned by this run' do
    allow(SecureRandom).to receive(:uuid).and_return('owned-lock')

    perform_job

    expect(Redis::Alfred).to have_received(:delete_if_equals)
      .with('rotta:uazapi:history-reconciliation:lock', 'owned-lock')
    expect(Redis::Alfred).not_to have_received(:delete)
  end

  it 'reconciles a failed legacy message with a confirmed provider read without replaying its content' do
    conversation = create(:conversation, account_id: described_class::ACCOUNT_ID)
    create(:message, conversation: conversation, account_id: described_class::ACCOUNT_ID,
                     message_type: :outgoing, status: :failed, source_id: '5511000000000:outgoing-1')
    stub_request(:post, 'https://uazapi.test/message/find').to_return(
      status: 200,
      body: { messages: [{ id: '5511000000000:outgoing-1', messageid: 'outgoing-1', fromMe: true,
                           status: 'Read', timestamp: Time.current.to_i,
                           text: 'Do not copy message text into receipt', quoted: { messageid: 'unrelated-quoted-id' } }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/messages_update')
      .to_return(status: 200, body: { ok: true }.to_json)

    perform_job

    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/messages_update')
      .with { |request| JSON.parse(request.body).fetch('data') == {
        'messageids' => ['outgoing-1', '5511000000000:outgoing-1'], 'status' => 'Read'
      } }).to have_been_made.once
    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')).not_to have_been_made
  end

  it 'does not convert a queued provider message into a successful send' do
    conversation = create(:conversation, account_id: described_class::ACCOUNT_ID)
    create(:message, conversation: conversation, account_id: described_class::ACCOUNT_ID,
                     message_type: :outgoing, status: :failed, source_id: 'outgoing-1')
    stub_request(:post, 'https://uazapi.test/message/find').to_return(
      status: 200,
      body: { messages: [{ messageid: 'outgoing-1', fromMe: true, status: 'Queued', timestamp: Time.current.to_i }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    perform_job

    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/messages_update')).not_to have_been_made
    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')).not_to have_been_made
  end

  it 'also recognizes the legacy storage ID without replaying existing history' do
    conversation = create(:conversation, account_id: described_class::ACCOUNT_ID)
    create(:message, conversation: conversation, account_id: described_class::ACCOUNT_ID, source_id: '5511000000000:incoming-1')

    perform_job

    expect(a_request(:post, 'http://rails:3000/webhooks/uazapi/webhook-token/history')
      .with { |request| JSON.parse(request.body).dig('data', 'messageid') == 'incoming-1' }).not_to have_been_made
  end

  it 'uses an overlap from the last successful reconciliation and advances the cursor' do
    last_success_at = 2.minutes.ago
    allow(Redis::Alfred).to receive(:get)
      .with('rotta:uazapi:history-reconciliation:last-success-at')
      .and_return(last_success_at.to_f.to_s)

    perform_job

    expect(Redis::Alfred).to have_received(:set)
      .with('rotta:uazapi:history-reconciliation:last-success-at', kind_of(Float))
  end
end
