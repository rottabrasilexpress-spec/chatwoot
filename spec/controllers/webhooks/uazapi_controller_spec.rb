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
  end
end
