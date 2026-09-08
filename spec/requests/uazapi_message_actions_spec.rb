require 'rails_helper'

RSpec.describe 'Uazapi message actions', type: :request do
  let!(:account) { create(:account) }
  let!(:api_channel) { create(:channel_api, account: account) }
  let!(:api_inbox) { create(:inbox, channel: api_channel, account: account) }
  let!(:contact_inbox) do
    create(:contact_inbox, inbox: api_inbox, source_id: '5511965927865@s.whatsapp.net')
  end
  let!(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: api_inbox,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox
    )
  end
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:message) do
    create(
      :message,
      account: account,
      conversation: conversation,
      message_type: :outgoing,
      content: 'Mensagem original',
      source_id: '3EBTESTE123'
    )
  end

  before do
    create(:inbox_member, inbox: api_inbox, user: agent)
    stub_const('ENV', ENV.to_h.merge(
                       'ROTTABRASIL_UAZAPI_BASE_URL' => 'https://transportadoras.uazapi.com',
                       'ROTTABRASIL_UAZAPI_TOKEN' => 'test-token'
                     ))
  end

  def action_url(action)
    "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/#{action}"
  end

  it 'edits the message in Uazapi and Chatwoot' do
    stub_request(:post, 'https://transportadoras.uazapi.com/message/edit')
      .with(body: { id: '3EBTESTE123', text: 'Mensagem corrigida' })
      .to_return(status: 200, body: { id: '3EBTESTE123' }.to_json)

    post action_url('edit'), params: { text: 'Mensagem corrigida' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(message.reload.content).to eq('Mensagem corrigida')
    expect(message.content_attributes['edited']).to be(true)
  end

  it 'reacts and pins through the provider' do
    stub_request(:post, 'https://transportadoras.uazapi.com/message/react')
      .with(body: { number: '5511965927865', text: '👍', id: '3EBTESTE123' })
      .to_return(status: 200, body: { success: true }.to_json)
    stub_request(:post, 'https://transportadoras.uazapi.com/message/pin')
      .with(body: { id: '3EBTESTE123', pin: true, duration: 7 })
      .to_return(status: 200, body: { success: true }.to_json)

    post action_url('react'), params: { emoji: '👍' }, headers: agent.create_new_auth_token, as: :json
    post action_url('pin'), params: { pin: true, duration: 7 }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(message.reload.content_attributes['rotta_reaction']).to eq('👍')
    expect(message.content_attributes['rotta_pinned']).to be(true)
    expect(message.content_attributes['rotta_pinned_duration']).to eq(7)
  end

  it 'stores a per-agent favorite without exposing provider state' do
    post action_url('star'), params: { starred: true }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(MessageStar.exists?(message: message, user: agent)).to be(true)
    expect(response.parsed_body['starred']).to be(true)

    post action_url('star'), params: { starred: false }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(MessageStar.exists?(message: message, user: agent)).to be(false)
    expect(response.parsed_body['starred']).to be(false)
  end
end
