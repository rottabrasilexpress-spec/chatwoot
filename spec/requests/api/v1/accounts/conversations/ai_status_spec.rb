require 'rails_helper'

RSpec.describe 'Conversation AI status API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) do
    create(:channel_whatsapp, account: account, sync_templates: false,
                              validate_provider_config: false).inbox
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(RottaAiStatus::Client, statuses_for: { '5511991234567@s.whatsapp.net' => 'blocked' }) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/ai_status" }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    conversation.contact_inbox.update!(source_id: '+55 11 99123-4567')
    allow(RottaAiStatus::Client).to receive(:new).and_return(client)
  end

  it 'returns the effective state by conversation without exposing the WhatsApp JID' do
    post path,
         params: { conversation_ids: [conversation.display_id] },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body)).to eq(
      'statuses' => [{ 'conversation_id' => conversation.display_id.to_s, 'state' => 'blocked' }]
    )
    expect(client).to have_received(:statuses_for).with(['5511991234567@s.whatsapp.net'])
  end

  it 'uses the contact phone for a UAZAPI API inbox with an opaque source ID' do
    api_channel = create(:channel_api, account: account)
    api_inbox = api_channel.inbox
    create(:inbox_member, user: agent, inbox: api_inbox)
    api_conversation = create(:conversation, account: account, inbox: api_inbox)
    api_conversation.contact.update!(phone_number: '+55 11 99123-4567')
    api_conversation.contact_inbox.update!(source_id: SecureRandom.uuid)

    post path,
         params: { conversation_ids: [api_conversation.display_id] },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body).dig('statuses', 0, 'state')).to eq('blocked')
    expect(client).to have_received(:statuses_for).with(['5511991234567@s.whatsapp.net'])
  end

  it 'returns unknown when the conversation has no exact WhatsApp source ID' do
    conversation.contact_inbox.update!(source_id: 'not-a-phone')

    post path,
         params: { conversation_ids: [conversation.display_id] },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body).dig('statuses', 0, 'state')).to eq('unknown')
    expect(client).to have_received(:statuses_for).with([])
  end

  it 'does not query AI pause status for non-WhatsApp conversations' do
    widget_inbox = create(:inbox, account: account, channel: create(:channel_widget, account: account))
    widget_conversation = create(:conversation, account: account, inbox: widget_inbox)
    create(:inbox_member, user: agent, inbox: widget_inbox)

    post path,
         params: { conversation_ids: [widget_conversation.display_id] },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body).dig('statuses', 0, 'state')).to eq('unknown')
    expect(client).to have_received(:statuses_for).with([])
  end

  it 'rejects an oversized batch' do
    post path,
         params: { conversation_ids: Array.new(101, conversation.display_id) },
         headers: agent.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(client).not_to have_received(:statuses_for)
  end

  it 'requires an authenticated agent' do
    post path, params: { conversation_ids: [conversation.display_id] }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(client).not_to have_received(:statuses_for)
  end
end
