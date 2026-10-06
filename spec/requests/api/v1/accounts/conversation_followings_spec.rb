require 'rails_helper'

RSpec.describe 'Shared conversation following', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :administrator) }
  let(:other_agent) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversation_followings" }

  it 'shares membership and returns the latest public message despite Message default ordering' do
    create(:message, account: account, conversation: conversation, content: 'Old', created_at: 2.hours.ago)
    latest = create(:message, account: account, conversation: conversation, content: 'Latest', created_at: 1.hour.ago)
    create(:message, account: account, conversation: conversation, content: 'Private', private: true)
    patch "#{path}/#{conversation.display_id}", headers: agent.create_new_auth_token, as: :json
    get path, headers: other_agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('items', 0, 'last_message', 'id')).to eq(latest.id)
    expect(response.parsed_body.dig('items', 0, 'last_message', 'content')).to eq('Latest')
  end

  it 'keeps one record on repeated inclusion and does not change labels or conversation state' do
    labels = conversation.label_list.dup
    status = conversation.status
    2.times { patch "#{path}/#{conversation.display_id}", headers: agent.create_new_auth_token, as: :json }
    expect(ConversationFollowing.where(conversation: conversation).count).to eq(1)
    expect(conversation.reload.label_list).to eq(labels)
    expect(conversation.status).to eq(status)
    delete "#{path}/#{conversation.display_id}", headers: other_agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(ConversationFollowing.where(conversation: conversation)).to be_empty
    expect(Conversation.exists?(conversation.id)).to be(true)
  end

  it 'does not skip the next item when an earlier following is removed' do
    first = create(:conversation, account: account)
    later = create(:conversation, account: account)
    low = ConversationFollowing.create!(account: account, conversation: first)
    high = ConversationFollowing.create!(account: account, conversation: later)
    high.destroy!
    get path, params: { before_id: high.id }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['items'].map { |item| item['id'] }).to include(first.display_id)
    expect(response.parsed_body['next_cursor']).to eq(low.id)
  end

  it 'requires authentication and cannot read another account conversation' do
    get path, as: :json
    expect(response).to have_http_status(:unauthorized)
    other = create(:account)
    get "/api/v1/accounts/#{other.id}/conversation_followings", headers: agent.create_new_auth_token, as: :json
    expect(response).not_to have_http_status(:ok)
  end
end
