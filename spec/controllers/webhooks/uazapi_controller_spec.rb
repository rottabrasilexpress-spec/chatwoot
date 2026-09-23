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

  def post_uazapi(payload = nil, token: webhook_token, **payload_keywords)
    payload ||= payload_keywords
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

    it 'records a sanitized terminal delivery for a successful webhook' do
      payload = {
        event: 'contacts',
        instance: 'rotta',
        data: [{ id: '5511999999999@s.whatsapp.net', name: 'Nome que não deve ser armazenado' }]
      }

      post_uazapi(payload)

      delivery = UazapiWebhookDelivery.order(:id).last
      expect(delivery).to have_attributes(
        account_id: account.id,
        event: 'contacts',
        status: 'ignored',
        attempts: 1,
        response_status: 200,
        error_class: nil,
        error_message: nil
      )
      expect(delivery.payload_digest).to eq(Digest::SHA256.hexdigest(payload.to_json))
      expect(delivery.correlation_id).to be_present
      expect(delivery.metadata['top_level_keys']).to include('event', 'instance', 'data')
      expect(delivery.metadata.to_json).not_to include('Nome que não deve ser armazenado', '5511999999999')
    end

    it 'records invalid JSON as a terminal failed delivery' do
      post "/webhooks/uazapi/#{webhook_token}",
           params: '{"event":',
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:bad_request)

      delivery = UazapiWebhookDelivery.order(:id).last
      expect(delivery).to have_attributes(
        event: 'unknown',
        status: 'failed',
        response_status: 400,
        error_class: 'JSON::ParserError',
        error_message: 'invalid_json'
      )
    end

    it 'records processing failures without exposing the exception message' do
      allow(RottaUazapiCallEventService).to receive(:perform).and_raise(RuntimeError, 'provider phone 5511999999999 secret text')

      post_uazapi(event: 'call', data: { call: { id: 'uazapi-failed-call' } })

      expect(response).to have_http_status(:unprocessable_entity)

      delivery = UazapiWebhookDelivery.order(:id).last
      expect(delivery).to have_attributes(
        event: 'call',
        status: 'failed',
        response_status: 422,
        error_class: 'RuntimeError',
        error_message: 'processing_failed'
      )
      expect(delivery.error_message).not_to include('5511999999999', 'secret text')
    end

    it 'keeps the webhook flow available when the audit ledger is unavailable' do
      allow(UazapiWebhookDelivery).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'audit table unavailable')

      post_uazapi(event: 'contacts', data: [])

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('ok' => true, 'event' => 'contacts')
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

    it 'updates the original incoming message when Uazapi sends an edit event' do
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
      original_id = 'uazapi-original-incoming-edit'
      original_payload = {
        event: 'messages',
        message: {
          messageId: original_id,
          chatid: '5511999999999@s.whatsapp.net',
          fromMe: false,
          type: 'text',
          text: 'Texto antes da edição'
        }
      }
      edited_payload = {
        event: 'messages',
        message: {
          messageId: 'uazapi-edit-event-1',
          edited: original_id,
          chatid: '5511999999999@s.whatsapp.net',
          fromMe: false,
          type: 'text',
          text: 'Texto final depois da edição'
        }
      }

      post_uazapi(original_payload)
      canonical_message = conversation.messages.incoming.find_by!(source_id: original_id)

      expect do
        post_uazapi(edited_payload)
      end.not_to change { conversation.messages.incoming.count }

      expect(response).to have_http_status(:success)
      expect(conversation.messages.incoming.count).to eq(1)
      expect(canonical_message.reload.content).to eq('Texto final depois da edição')
      expect(canonical_message.content_attributes).to include(
        'edited' => true,
        'uazapi_edit_message_id' => 'uazapi-edit-event-1'
      )
    end

    it 'uses the original provider ID when an edit event arrives before its original message' do
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
      original_id = 'uazapi-original-before-edit'

      post_uazapi(
        event: 'messages',
        message: {
          messageId: 'uazapi-edit-event-before-original',
          edited: original_id,
          chatid: '5511999999999@s.whatsapp.net',
          fromMe: false,
          type: 'text',
          text: 'Texto final da edição antecipada'
        }
      )
      post_uazapi(
        event: 'messages',
        message: {
          messageId: original_id,
          chatid: '5511999999999@s.whatsapp.net',
          fromMe: false,
          type: 'text',
          text: 'Texto original atrasado'
        }
      )

      expect(response).to have_http_status(:success)
      expect(conversation.messages.incoming.count).to eq(1)
      expect(conversation.messages.incoming.first).to have_attributes(
        source_id: original_id,
        content: 'Texto final da edição antecipada'
      )
    end

    it 'persists an incoming media attachment from the Uazapi file URL' do
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
      media_url = 'https://example.com/uazapi-image.jpg'
      stub_request(:get, media_url).to_return(
        status: 200,
        body: Rails.root.join('spec/assets/avatar.png').binread,
        headers: { 'Content-Type' => 'image/png' }
      )
      payload = {
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-incoming-media-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: false,
            type: 'image',
            fileURL: media_url
          }
        }
      }

      expect(RottaUazapiMessageMediaSyncJob).to receive(:perform_later).with(
        account.id,
        kind_of(Integer),
        'uazapi-incoming-media-1',
        media_url,
        'image'
      )
      expect do
        post_uazapi(payload)
      end.to change { conversation.messages.where(source_id: 'uazapi-incoming-media-1').count }.from(0).to(1)

      expect(response).to have_http_status(:success)
      message = conversation.messages.find_by!(source_id: 'uazapi-incoming-media-1')
      expect(message.content).to eq('[image]')
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

    it 'deduplicates repeated incoming messages when Uazapi omits the provider ID' do
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
          chatid: '5511999999999@s.whatsapp.net',
          from_me: false,
          type: 'text',
          text: 'Evento sem ID, uma única vez',
          timestamp: 1_789_668_000
        }
      }

      post_uazapi(payload)
      first_message = conversation.messages.incoming.find_by!(content: 'Evento sem ID, uma única vez')

      expect do
        post_uazapi(payload)
      end.not_to change { conversation.messages.incoming.count }

      expect(first_message.source_id).to start_with('uazapi:fingerprint:')
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
        status: 'sent',
        sender: nil
      )
      expect(message.content_attributes['external_echo']).to be(true)
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => [message.id])
      expect(UazapiWebhookDelivery.order(:id).last).to have_attributes(
        event: 'messages',
        provider_message_id: 'uazapi-outgoing-ai-1',
        conversation_id: conversation.id,
        status: 'persisted'
      )
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
      expect(chatwoot_message.content_attributes).to include(
        'external_echo' => true,
        'rotta_uazapi' => true,
        'uazapi_track_source' => 'chatwoot',
        'uazapi_track_id' => "message-#{chatwoot_message.id}"
      )
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => [chatwoot_message.id])
    end

    it 'correlates a pending Chatwoot send when the echo has no track id' do
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
        content: 'Eco chegou antes do ID',
        content_attributes: {
          'rotta_uazapi_pending_echo' => true,
          'external_echo' => true
        }
      )

      payload = {
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-race-echo-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: true,
            wasSentByApi: true,
            type: 'text',
            text: chatwoot_message.content
          }
        }
      }

      expect do
        post_uazapi(payload)
      end.not_to change { conversation.messages.outgoing.count }

      expect(chatwoot_message.reload.source_id).to eq('uazapi-race-echo-1')
      expect(chatwoot_message.content_attributes).not_to have_key('rotta_uazapi_pending_echo')
    end

    it 'corrects a timed-out outgoing message when the successful Uazapi echo arrives' do
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
        status: :failed,
        external_error: 'Net::ReadTimeout',
        sender: create(:user, account: account),
        source_id: nil,
        content: 'Mensagem aceita pela Uazapi'
      )

      post_uazapi(
        event: 'messages',
        data: {
          message: {
            messageId: 'uazapi-late-echo-1',
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: true,
            wasSentByApi: true,
            track_source: 'chatwoot',
            track_id: "message-#{chatwoot_message.id}",
            type: 'text',
            text: chatwoot_message.content
          }
        }
      )

      expect(chatwoot_message.reload).to have_attributes(
        source_id: 'uazapi-late-echo-1',
        status: 'sent',
        external_error: nil
      )
    end

    it 'promotes an outgoing message when Uazapi sends a separated key and update status' do
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
      message = create(
        :message,
        account: account,
        inbox: api_inbox,
        conversation: conversation,
        message_type: :outgoing,
        status: :sent,
        source_id: 'uazapi-status-separated-1',
        content: 'Mensagem aguardando confirmação'
      )

      payload = {
        event: 'messages_update',
        data: {
          key: { id: message.source_id, remoteJid: '5511999999999@s.whatsapp.net' },
          update: { status: 3 }
        }
      }

      post_uazapi(payload)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('ok' => true, 'message_ids' => [message.id], 'status' => 'delivered')
      expect(message.reload).to have_attributes(status: 'delivered')
      expect(message.additional_attributes).to include(
        'uazapi_status' => 3,
        'uazapi_message_id' => message.source_id
      )
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

    it 'retains an incoming customer-deleted message and leaves an agent-only tombstone' do
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
      message = create(
        :message,
        account: account,
        inbox: api_inbox,
        conversation: conversation,
        message_type: :incoming,
        private: false,
        source_id: 'uazapi-customer-delete-1',
        content: 'Conteúdo que o cliente apagou'
      )
      allow(DeletedMessageContent).to receive(:encryption_ready?).and_return(true)

      post_uazapi(
        event: 'message_deleted',
        data: {
          message: {
            messageId: message.source_id,
            chatid: '5511999999999@s.whatsapp.net',
            fromMe: false
          }
        }
      )

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('ok' => true, 'event' => 'message_deleted', 'message_ids' => [message.id])
      expect(message.reload).to have_attributes(
        content: I18n.t('conversations.messages.deleted'),
        content_type: 'text'
      )
      expect(message.content_attributes).to include('deleted' => true, 'deleted_by' => 'customer')
      expect(message.deleted_message_content).to have_attributes(
        content: 'Conteúdo que o cliente apagou',
        source: 'customer'
      )
      expect(UazapiWebhookDelivery.order(:id).last).to have_attributes(
        event: 'message_deleted',
        status: 'persisted',
        conversation_id: conversation.id
      )
    end

    it 'recognizes every explicit customer-deletion event alias from the route' do
      %w[
        message_delete messages_delete message_deleted messages_deleted
        message_revoke messages_revoke message_revoked messages_revoked
      ].each do |route_event|
        post "/webhooks/uazapi/#{webhook_token}/#{route_event}",
             params: {}.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to include('ignored' => 'mensagem não localizada')
        expect(UazapiWebhookDelivery.order(:id).last.event).to eq(route_event)
      end
    end
  end
end
