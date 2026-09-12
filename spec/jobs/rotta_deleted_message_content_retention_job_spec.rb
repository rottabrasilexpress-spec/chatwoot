require 'rails_helper'

RSpec.describe RottaDeletedMessageContentRetentionJob, type: :job do
  it 'removes expired records and preserves active records' do
    expired = create(:deleted_message_content, expires_at: 1.minute.ago)
    active = create(:deleted_message_content, expires_at: 1.minute.from_now)

    described_class.perform_now

    expect(DeletedMessageContent.exists?(expired.id)).to be(false)
    expect(DeletedMessageContent.exists?(active.id)).to be(true)
  end
end
