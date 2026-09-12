require 'rails_helper'

RSpec.describe Rotta::CaioAttentionAlert do
  let!(:account) { create(:account) }
  let!(:caio) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:occurred_at) { Time.zone.parse('2026-09-11 12:00:00.123456') }

  around do |example|
    with_modified_env(
      'ROTTABRASIL_CHATWOOT_ACCOUNT_ID' => account.id.to_s,
      'ROTTABRASIL_CAIO_USER_ID' => caio.id.to_s
    ) { example.run }
  end

  it 'builds a deterministic private payload only when the label is added' do
    attributes = { 'label_list' => [['Kelvin'], ['Kelvin', 'Caio Atenção']] }

    first = described_class.call(
      conversation: conversation,
      changed_attributes: attributes,
      occurred_at: occurred_at
    )
    second = described_class.call(
      conversation: conversation,
      changed_attributes: attributes,
      occurred_at: occurred_at
    )

    expect(first).to eq(second)
    expect(first).to include(
      recipient_pubsub_token: caio.pubsub_token,
      recipient_user_id: caio.id,
      conversation_id: conversation.display_id,
      inbox_id: inbox.id,
      label: 'caio-atencao'
    )
    expect(first).not_to include(:performer)
    expect(first[:contact]).to include(name: conversation.contact.name)
  end

  it 'accepts normalized label variants' do
    expect(
      described_class.call(
        conversation: conversation,
        changed_attributes: { label_list: [[], ['CAIO ATENÇÃO']] },
        occurred_at: occurred_at
      )
    ).to be_present
  end

  it 'does not alert when the label was already present' do
    expect(
      described_class.call(
        conversation: conversation,
        changed_attributes: { 'label_list' => [['Caio Atenção'], ['Caio Atenção', 'Kelvin']] },
        occurred_at: occurred_at
      )
    ).to be_nil
  end

  it 'fails closed when the configured user is absent' do
    with_modified_env 'ROTTABRASIL_CAIO_USER_ID' => nil do
      expect(
        described_class.call(
          conversation: conversation,
          changed_attributes: { 'label_list' => [[], ['Caio Atenção']] },
          occurred_at: occurred_at
        )
      ).to be_nil
    end
  end

  it 'does not resolve Caio by name' do
    caio.update!(name: 'Someone Else')

    expect(
      described_class.call(
        conversation: conversation,
        changed_attributes: { 'label_list' => [[], ['Caio Atenção']] },
        occurred_at: occurred_at
      )[:recipient_user_id]
    ).to eq(caio.id)
  end
end
