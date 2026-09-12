require 'rails_helper'

RSpec.describe Conversations::RequestAttentionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:requester) { create(:user, account: account, role: :agent) }
  let(:target) { create(:user, account: account, role: :agent) }

  around do |example|
    with_modified_env(
      'ROTTABRASIL_ATTENTION_REQUESTER_USER_ID' => requester.id.to_s,
      'ROTTABRASIL_CAIO_USER_ID' => target.id.to_s
    ) { example.run }
  end

  it 'sends a private alert only to the configured target with contact context' do
    allow(ActionCableBroadcastJob).to receive(:perform_later)

    result = described_class.new(conversation: conversation, requester: requester).perform

    expect(ActionCableBroadcastJob).to have_received(:perform_later).with(
      [target.pubsub_token],
      Events::Types::CONVERSATION_ATTENTION_REQUESTED,
      hash_including(
        kind: 'attention-requested',
        recipient_user_id: target.id,
        contact: hash_including(name: conversation.contact.name)
      )
    )
    expect(result).not_to include(:requester, :requester_name)
  end

  it 'does not send when the target is not configured' do
    with_modified_env 'ROTTABRASIL_CAIO_USER_ID' => nil, 'ROTTABRASIL_ATTENTION_TARGET_USER_ID' => nil do
      expect do
        described_class.new(conversation: conversation, requester: requester).perform
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
