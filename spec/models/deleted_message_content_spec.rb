require 'rails_helper'

RSpec.describe DeletedMessageContent, type: :model do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: inbox) }

  it 'reports active content only before the retention deadline' do
    active = build(:deleted_message_content, message: message, account: account, conversation: conversation,
                   deleted_at: 1.hour.ago, expires_at: 1.hour.from_now)
    expired = build(:deleted_message_content, message: build(:message, account: account, conversation: conversation, inbox: inbox),
                    account: account, conversation: conversation, deleted_at: 3.days.ago, expires_at: 1.hour.ago)

    expect(active).to be_active
    expect(expired).not_to be_active
  end

  it 'accepts only customer-origin retention records' do
    record = build(:deleted_message_content, message: message, account: account, conversation: conversation,
                   source: 'agent', deleted_at: 1.hour.ago, expires_at: 1.hour.from_now)

    expect(record).not_to be_valid
    expect(record.errors[:source]).to be_present
  end
end
