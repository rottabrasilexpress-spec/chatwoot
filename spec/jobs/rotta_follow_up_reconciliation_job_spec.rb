require 'rails_helper'

RSpec.describe RottaFollowUpReconciliationJob, type: :job do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:candidate) do
    { 'conversation_id' => conversation.display_id.to_s, 'stage_label' => 'primeiro-contato', 'account_id' => account.id.to_s }
  end
  let(:cache_key) { "rotta_follow_up:stage_reconcile:#{account.id}:#{conversation.display_id}:primeiro-contato" }

  before do
    allow(Redis::Alfred).to receive(:delete_if_equals)
    allow(Redis::Alfred).to receive(:set)
  end

  it 'does not recreate a follow-up when its label was removed while waiting' do
    allow(RottaFollowUp::AdminClient).to receive(:request)

    described_class.perform_now(account.id, [candidate])

    expect(RottaFollowUp::AdminClient).not_to have_received(:request)
    expect(Redis::Alfred).to have_received(:delete_if_equals).with(cache_key, 'in_progress')
  end

  it 'confirms the exact account, conversation and stage before releasing the reservation' do
    conversation.update_labels(['primeiro-contato'])
    allow(RottaFollowUp::AdminClient).to receive(:request).with(action: 'reconcile', account_id: account.id, conversations: [candidate])
      .and_return(RottaFollowUp::AdminClient::Response.new(status: 200, body: { 'ok' => true }))
    allow(RottaFollowUp::AdminClient).to receive(:request).with(action: 'list', account_id: account.id, operational_only: true)
      .and_return(RottaFollowUp::AdminClient::Response.new(status: 200, body: {
        'jobs' => [{ 'account_id' => account.id.to_s, 'conversation_id' => conversation.display_id.to_s,
                     'current_label' => 'primeiro-contato', 'status' => 'pending' }]
      }))

    described_class.perform_now(account.id, [candidate])

    expect(Redis::Alfred).not_to have_received(:set)
    expect(Redis::Alfred).to have_received(:delete_if_equals).with(cache_key, 'in_progress')
  end

  it 'does not reconcile if another follow-up stage became active while waiting' do
    conversation.update_labels(%w[primeiro-contato segundo-contato])
    allow(RottaFollowUp::AdminClient).to receive(:request)

    described_class.perform_now(account.id, [candidate])

    expect(RottaFollowUp::AdminClient).not_to have_received(:request)
  end

  it 'retains a real upstream error for maintenance without sending a message' do
    conversation.update_labels(['primeiro-contato'])
    allow(RottaFollowUp::AdminClient).to receive(:request)
      .and_return(RottaFollowUp::AdminClient::Response.new(status: 503, body: { 'error' => 'upstream unavailable' }))

    described_class.perform_now(account.id, [candidate])

    expect(Redis::Alfred).to have_received(:set).with(cache_key, 'upstream unavailable', ex: 20)
  end
end
