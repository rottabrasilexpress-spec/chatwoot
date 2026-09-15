require 'rails_helper'

RSpec.describe GlobalAiAssistant::ActionService do
  let(:account) { instance_double(Account) }
  let(:conversation_scope) { instance_double(ActiveRecord::Relation) }
  let(:conversation) do
    instance_double(
      Conversation,
      display_id: '2165',
      contact: instance_double(Contact, name: 'Cliente teste')
    )
  end

  before do
    allow(account).to receive(:conversations).and_return(conversation_scope)
    allow(conversation_scope).to receive(:find_by!).with(display_id: '2165').and_return(conversation)
    allow(Pundit).to receive(:authorize)
  end

  it 'exposes follow-up label removal through the same confirmed action seam' do
    result = described_class.new(
      account: account,
      user: instance_double(User),
      action: 'follow_up_remove_label',
      conversation_id: '2165',
      confirmed: false,
      params: { 'label' => 'Primeiro contato', 'job_id' => 'pending:2165:primeiro-contato' }
    ).call

    expect(result).to include(
      ok: false,
      confirmation_required: true,
      action: 'follow_up_remove_label',
      conversation_id: '2165'
    )
  end

  it 'rejects status changes because status remains under native Chatwoot controls' do
    service = described_class.new(
      account: account,
      user: instance_double(User),
      action: 'set_status',
      conversation_id: '2165',
      confirmed: true,
      params: { 'status' => 'resolved' }
    )

    expect { service.call }.to raise_error(ArgumentError, 'Ação não permitida.')
  end
end
