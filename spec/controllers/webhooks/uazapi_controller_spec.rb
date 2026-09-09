require 'rails_helper'

RSpec.describe 'Webhooks::UazapiController', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511999999999') }
  let(:webhook_token) { 'test-uazapi-webhook-token' }

  before do
    stub_const('Webhooks::UazapiController::ACCOUNT_ID', account.id)
    stub_const('Webhooks::UazapiController::WEBHOOK_TOKEN', webhook_token)
  end

  def post_uazapi(payload, token: webhook_token)
    post "/webhooks/uazapi/#{token}",
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json' }
  end

  describe 'POST /webhooks/uazapi/:token' do
    it 'queues a profile sync for contacts events matching a Chatwoot contact' do
      contact
      payload = {
        event: 'contacts',
        instance: 'rotta',
        data: [{ id: '5511999999999@s.whatsapp.net', name: 'Contato atualizado' }]
      }

      expect do
        post_uazapi(payload)
      end.to have_enqueued_job(RottaUazapiContactAvatarSyncJob).with(account.id, contact.id).exactly(:once)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('ok' => true, 'event' => 'contacts')
    end

    it 'deduplicates repeated contacts in the same event' do
      contact
      payload = {
        event: 'contacts',
        data: [
          { jid: '5511999999999@s.whatsapp.net' },
          { jid: '5511999999999@s.whatsapp.net' }
        ]
      }

      expect do
        post_uazapi(payload)
      end.to have_enqueued_job(RottaUazapiContactAvatarSyncJob).with(account.id, contact.id).exactly(:once)
    end

    it 'rejects an invalid webhook token without enqueuing work' do
      allow(RottaUazapiContactAvatarSyncJob).to receive(:perform_later)

      post_uazapi({ event: 'contacts', data: [{ id: '5511999999999@s.whatsapp.net' }] }, token: 'wrong-token')

      expect(response).to have_http_status(:unauthorized)
      expect(RottaUazapiContactAvatarSyncJob).not_to have_received(:perform_later)
    end

    it 'creates an incoming message immediately when Uazapi sends a messages event' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )

      payload = {
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-incoming-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: false,
            type: 'text',
            text: 'Mensagem recebida em tempo real'
          }
        }
      }

      expect do
        post_uazapi(payload)
      end.to change { conversation.messages.where(source_id: 'uazapi-incoming-1').count }.from(0).to(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => kind_of(Array))
      expect(conversation.messages.find_by!(source_id: 'uazapi-incoming-1').content).to eq('Mensagem recebida em tempo real')
    end

    it 'deduplicates repeated incoming messages by provider ID' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      payload = {
        event: 'messages',
        message: {
          message_id: 'uazapi-incoming-duplicate',
          chatid: '5511999999999@s.whatsapp.net',
          from_me: false,
          text: 'Uma única vez'
        }
      }

      post_uazapi(payload)
      expect do
        post_uazapi(payload)
      end.not_to change { conversation.messages.where(source_id: 'uazapi-incoming-duplicate').count }

      expect(response.parsed_body).to include('ok' => true, 'ignored' => 'mensagem duplicada')
    end

    it 'persists an outgoing API reply when Uazapi echoes a message sent by the instance' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )

      payload = {
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-outgoing-ai-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: true,
            wasSentByApi: true,
            type: 'text',
            text: 'Resposta enviada pela IA'
          }
        }
      }

      expect do
        post_uazapi(payload)
      end.to change { conversation.messages.outgoing.where(source_id: 'uazapi-outgoing-ai-1').count }.from(0).to(1)

      message = conversation.messages.find_by!(source_id: 'uazapi-outgoing-ai-1')
      expect(message).to have_attributes(
        content: 'Resposta enviada pela IA',
        status: 'delivered',
        sender: nil
      )
      expect(message.content_attributes['external_echo']).to be(true)
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => [message.id])
    end

    it 'correlates a Chatwoot-originated echo by track_id instead of duplicating it' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      chatwoot_message = create(
        :message,
        account: account,
        inbox: api_inbox,
        conversation: conversation,
        message_type: :outgoing,
        sender: create(:user, account: account),
        source_id: nil,
        content: 'Resposta já criada no Chatwoot'
      )

      payload = {
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-chatwoot-echo-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: true,
            wasSentByApi: true,
            track_source: 'chatwoot',
            track_id: "message-#{chatwoot_message.id}",
            type: 'text',
            text: chatwoot_message.content
          }
        }
      }

      expect do
        post_uazapi(payload)
      end.not_to change { conversation.messages.outgoing.count }

      expect(chatwoot_message.reload.source_id).to eq('uazapi-chatwoot-echo-1')
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => [chatwoot_message.id])
    end

    it 'creates a realtime voice call message from a Uazapi call event' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      payload = {
        event: 'call',
        instance: 'rotta',
        data: {
          calls: [{
            id: 'uazapi-call-1',
            chatid: '5511999999999@s.whatsapp.net',
            from: '5511999999999@s.whatsapp.net',
            direction: 'inbound',
            status: 'RINGING',
            timestamp: Time.current.to_i
          }]
        }
      }

      expect do
        post_uazapi(payload)
      end.to change { conversation.messages.voice_calls.count }.from(0).to(1)
         .and change(Call, :count).by(1)

      call = Call.find_by!(provider: :whatsapp, provider_call_id: 'uazapi-call-1')
      expect(call).to have_attributes(direction: 'incoming', status: 'ringing', message_id: be_present)
      expect(response.parsed_body).to include('ok' => true, 'event' => 'call', 'provider_call_ids' => ['uazapi-call-1'])
      expect(conversation.messages.voice_calls.last.call).to eq(call)
    end

    it 'updates a voice call in place and deduplicates webhook retries' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )
      base = {
        event: 'call',
        data: {
          call: {
            id: 'uazapi-call-2',
            chatid: '5511999999999@s.whatsapp.net',
            from: '5511999999999@s.whatsapp.net',
            direction: 'inbound'
          }
        }
      }

      post_uazapi(base.merge(data: { call: base[:data][:call].merge(status: 'RINGING') }))
      expect do
        post_uazapi(base.merge(data: { call: base[:data][:call].merge(status: 'ANSWERED') }))
        post_uazapi(base.merge(data: { call: base[:data][:call].merge(status: 'TERMINATED', duration: 12) }))
      end.to change { conversation.messages.voice_calls.count }.by(0)

      call = Call.find_by!(provider_call_id: 'uazapi-call-2')
      expect(call.reload).to have_attributes(status: 'completed', duration_seconds: 12)
      expect(call.message.content_attributes.dig('data', 'status')).to eq('completed')
      expect(response.parsed_body).to include('ok' => true, 'provider_call_ids' => ['uazapi-call-2'])
    end

    it 'accepts the event in the dynamic Uazapi webhook URL' do
      api_channel = create(:channel_api, account: account)
      api_inbox = create(:inbox, channel: api_channel, account: account)
      contact_inbox = create(:contact_inbox, inbox: api_inbox, contact: contact, source_id: '5511999999999@s.whatsapp.net')
      conversation = create(
        :conversation,
        account: account,
        inbox: api_inbox,
        contact: contact,
        contact_inbox: contact_inbox
      )

      post "/webhooks/uazapi/#{webhook_token}/messages/text",
           params: {
             message: {
               id: 'uazapi-dynamic-route',
               chatid: '5511999999999@s.whatsapp.net',
               from_me: false,
               text: 'Evento veio pela rota'
             }
           }.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:success)
      expect(conversation.messages.find_by!(source_id: 'uazapi-dynamic-route').content).to eq('Evento veio pela rota')
    end
  end
end
