require 'rails_helper'

RSpec.describe 'Conversation attention request API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:requester) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:target) { create(:user, account: account, role: :agent, name: 'Caio', display_name: 'Caio') }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/request_attention" }

  before do
    create(:inbox_member, user: requester, inbox: inbox)
    create(:inbox_member, user: other_agent, inbox: inbox)
  end

  around do |example|
    with_modified_env(
      'ROTTABRASIL_ATTENTION_REQUESTER_USER_ID' => requester.id.to_s,
      'ROTTABRASIL_CAIO_USER_ID' => target.id.to_s
    ) { example.run }
  end

  it 'returns created and broadcasts only to the configured target' do
    allow(ActionCableBroadcastJob).to receive(:perform_later)

    post path, headers: requester.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(ActionCableBroadcastJob).to have_received(:perform_later).with(
      [target.pubsub_token],
      Events::Types::CONVERSATION_ATTENTION_REQUESTED,
      hash_including(recipient_user_id: target.id, kind: 'attention-requested')
    )
  end

  it 'forbids another agent even when they can view the conversation' do
    post path, headers: other_agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
