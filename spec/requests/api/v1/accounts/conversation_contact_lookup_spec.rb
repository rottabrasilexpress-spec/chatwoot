require 'rails_helper'

RSpec.describe 'Conversation contact lookup', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Kelvin Martins', phone_number: '+5511965927865') }
  let(:conversation) { create(:conversation, account: account, contact: contact, status: :resolved) }

  before do
    create(:inbox_member, user: agent, inbox: conversation.inbox)
    conversation.label_list.add('arquivado')
    conversation.save!
    create(:message, conversation: conversation, account: account, content: 'Older message', created_at: 1.hour.ago)
    create(:message, conversation: conversation, account: account, content: 'Latest message')
  end

  it 'returns complete cards with archive status and one latest message, not the entire history' do
    get "/api/v1/accounts/#{account.id}/conversations/search",
        params: { q: '11965927865', contact_search: 'true' },
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    card = response.parsed_body.dig('data', 'payload').first
    expect(card['id']).to eq(conversation.display_id)
    expect(card.dig('meta', 'sender', 'name')).to eq('Kelvin Martins')
    expect(card['status']).to eq('resolved')
    expect(card['labels']).to include('arquivado')
    expect(card['messages'].length).to eq(1)
    expect(card['messages'].first['content']).to eq('Latest message')
  end
end
