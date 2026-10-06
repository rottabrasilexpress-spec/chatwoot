require 'rails_helper'

RSpec.describe 'Individual conversation review points', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/review_points" }
  let(:point) do
    { id: 'review-one', view: 'all', title: 'Todos', name: 'Francine', conversation_id: 1,
      context: { status: 'all', assigneeType: 'all', filters: [] }, remaining: [{ id: 2, name: 'Eldon' }] }
  end

  it 'starts empty without creating a row on a read' do
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('views' => {}, 'history' => [])
    expect(ConversationReviewState.count).to eq(0)
  end

  it 'persists across reads without touching UI settings or conversations' do
    patch path, headers: agent.create_new_auth_token, params: { points: [point] }, as: :json
    expect(response).to have_http_status(:ok)
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('views', 'all', 'remaining', 0, 'name')).to eq('Eldon')
    expect(Conversation.count).to eq(0)
    expect(agent.reload.ui_settings).not_to have_key('conversation_review_points')
  end

  it 'does not expose another agent points' do
    patch path, headers: agent.create_new_auth_token, params: { points: [point] }, as: :json
    get path, headers: other_agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('views' => {}, 'history' => [])
  end

  it 'keeps only five historic points and bounds the saved sequence' do
    7.times do |index|
      patch path, headers: agent.create_new_auth_token,
                  params: { points: [point.merge(id: "review-#{index}", remaining: Array.new(220) { { id: 2, name: 'Eldon' } })] }, as: :json
    end
    expect(response.parsed_body['history'].length).to eq(5)
    expect(response.parsed_body.dig('views', 'all', 'remaining').length).to eq(200)
    expect(ConversationReviewState.count).to eq(1)
  end

  it 'preserves points from other views on a partial update' do
    patch path, headers: agent.create_new_auth_token, params: { points: [point] }, as: :json
    patch path, headers: agent.create_new_auth_token, params: { points: [point.merge(id: 'two', view: 'archived')] }, as: :json
    expect(response.parsed_body['views'].keys).to contain_exactly('all', 'archived')
  end

  it 'requires authentication' do
    get path, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'preserves numeric filter values across persistence' do
    filtered = point.deep_dup
    filtered[:context][:filters] = [{ attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [123] }]
    patch path, headers: agent.create_new_auth_token, params: { points: [filtered] }, as: :json
    expect(response.parsed_body.dig('views', 'all', 'context', 'filters', 0, 'values')).to eq([123])
  end

  it 'rejects missing context without writing state' do
    patch path, headers: agent.create_new_auth_token, params: { points: [point.except(:context)] }, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(ConversationReviewState.count).to eq(0)
  end
end
