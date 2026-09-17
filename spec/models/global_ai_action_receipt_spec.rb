require 'rails_helper'

RSpec.describe GlobalAiActionReceipt do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  it 'executes a confirmed AI action once when the same key is replayed' do
    calls = 0
    first = described_class.run!(
      account: account,
      user: user,
      idempotency_key: 'global-ai-follow-up-1',
      action_name: 'follow_up_cancel',
      conversation_display_id: 2165
    ) do
      calls += 1
      { ok: true, result: { cancelled: true } }
    end
    replay = described_class.run!(
      account: account,
      user: user,
      idempotency_key: 'global-ai-follow-up-1',
      action_name: 'follow_up_cancel',
      conversation_display_id: 2165
    ) do
      calls += 1
      { ok: true, result: { cancelled: true } }
    end

    expect(calls).to eq(1)
    expect(replay).to eq(first)
    expect(described_class.count).to eq(1)
  end

  it 'rejects reuse of a key for a different quick action' do
    described_class.run!(
      account: account,
      user: user,
      idempotency_key: 'global-ai-action-1',
      action_name: 'add_label',
      conversation_display_id: 2165
    ) { { ok: true } }

    expect do
      described_class.run!(
        account: account,
        user: user,
        idempotency_key: 'global-ai-action-1',
        action_name: 'send_public_message',
        conversation_display_id: 2165
      ) { { ok: true } }
    end.to raise_error(ArgumentError, 'Chave idempotente já foi usada para outra ação.')
  end
end
