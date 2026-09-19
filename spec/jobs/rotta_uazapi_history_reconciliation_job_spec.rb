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
    allow(Redis::Alfred).to receive(:delete)

    stub_request(:post, 'https://uazapi.test/chat/find').to_return(
      status: 200,
      body: { chats: [{ wa_chatid: '5511999999999@s.whatsapp.net', wa_lastMsgTimestamp: Time.current.to_i }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:post, 'https://uazapi.test/message/find').to_return(
      status: 200,
      body: {
        messages: [
          { messageid: 'incoming-1', chatid: '5511999999999@s.whatsapp.net', fromMe: false, text: 'Olá', timestamp: Time.current.to_i },
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
          .with { |request| JSON.parse(request.body).dig('data', 'messageid') == message_id }
      ).to have_been_made.once
    end
  end

  it 'does not overlap reconciliation runs' do
    allow(Redis::Alfred).to receive(:set).and_return(false)

    perform_job

    expect(a_request(:post, 'https://uazapi.test/chat/find')).not_to have_been_made
  end
end
