require 'rails_helper'

RSpec.describe Messages::CustomerDeletionService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: inbox, content: 'Lista de móveis') }
  let(:deleted_at) { Time.zone.parse('2026-09-11 12:00:00') }

  before do
    allow(DeletedMessageContent).to receive(:encryption_ready?).and_return(true)
  end

  it 'retains incoming customer content and leaves an agent-only tombstone' do
    expect do
      described_class.new(message: message, deleted_at: deleted_at).perform
    end.to change(DeletedMessageContent, :count).by(1)

    message.reload
    retained = message.deleted_message_content

    expect(retained.content).to eq('Lista de móveis')
    expect(retained.expires_at).to eq(deleted_at + DeletedMessageContent::RETENTION_PERIOD)
    expect(message.content).to eq(I18n.t('conversations.messages.deleted'))
    expect(message.content_attributes).to include('deleted' => true, 'deleted_by' => 'customer')
  end

  it 'fails closed when encryption is unavailable' do
    allow(DeletedMessageContent).to receive(:encryption_ready?).and_return(false)

    expect do
      described_class.new(message: message, deleted_at: deleted_at).perform
    end.to raise_error(Messages::CustomerDeletionService::EncryptionUnavailableError)
  end

  it 'does not retain an outgoing agent message' do
    outgoing = create(:message, account: account, conversation: conversation, inbox: inbox, message_type: :outgoing)

    expect do
      described_class.new(message: outgoing, deleted_at: deleted_at).perform
    end.to raise_error(Messages::CustomerDeletionService::UnsupportedMessageError)
  end
end
