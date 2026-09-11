require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::ConversationAiActions', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/captain/conversation_ai/actions" }

  it 'records the actor, target, state transition and result in the audit log' do
    expect do
      post endpoint,
           params: {
             conversation_id: conversation.display_id,
             action: 'set_status',
             status: 'pending'
           },
           headers: admin.create_new_auth_token,
           as: :json
    end.to change(Enterprise::AuditLog, :count).by(1)

    expect(response).to have_http_status(:success)

    audit = Enterprise::AuditLog.last
    expect(audit.action).to eq('conversation_ai_action')
    expect(audit.auditable).to eq(conversation)
    expect(audit.user).to eq(admin)
    expect(audit.request_uuid).to be_present
    expect(audit.audited_changes).to include(
      'source' => 'conversation_ai',
      'action' => 'set_status',
      'conversation_display_id' => conversation.display_id,
      'before' => include('status' => 'open'),
      'after' => include('status' => 'pending'),
      'result' => include('status' => 'pending')
    )
  end

  it 'does not allow an unauthenticated action' do
    post endpoint,
         params: {
           conversation_id: conversation.display_id,
           action: 'set_status',
           status: 'pending'
         },
         as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
