require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:context) do
    {
      user: agent,
      account: account,
      account_user: agent.account_users.find_by(account: account)
    }
  end

  before { create(:inbox_member, user: agent, inbox: inbox) }

  around do |example|
    with_modified_env 'ROTTABRASIL_ATTENTION_REQUESTER_USER_ID' => agent.id.to_s do
      example.run
    end
  end

  permissions :request_attention? do
    it 'allows only the configured requester with conversation access' do
      expect(subject).to permit(context, conversation)
    end

    it 'denies another agent even when that agent can view the conversation' do
      other_agent = create(:user, account: account, role: :agent)
      create(:inbox_member, user: other_agent, inbox: inbox)
      other_context = context.merge(
        user: other_agent,
        account_user: other_agent.account_users.find_by(account: account)
      )

      expect(subject).not_to permit(other_context, conversation)
    end
  end
end
