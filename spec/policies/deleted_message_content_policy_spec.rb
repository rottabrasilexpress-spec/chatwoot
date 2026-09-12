require 'rails_helper'

RSpec.describe DeletedMessageContentPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: inbox) }
  let(:record) { build(:deleted_message_content, message: message, account: account, conversation: conversation) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_context) do
    {
      user: agent,
      account: account,
      account_user: agent.account_users.find_by(account: account)
    }
  end

  before { create(:inbox_member, user: agent, inbox: inbox) }

  it 'allows an agent with conversation access' do
    expect(described_class.new(agent_context, record).show?).to be(true)
  end

  it 'denies a non-agent principal' do
    contact_context = { user: conversation.contact, account: account, account_user: nil }

    expect(described_class.new(contact_context, record).show?).to be(false)
  end
end
