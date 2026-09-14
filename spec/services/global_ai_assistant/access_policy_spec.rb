require 'rails_helper'

RSpec.describe GlobalAiAssistant::AccessPolicy do
  let(:account) { create(:account) }
  let(:kelvin) do
    create(:user, account: account, role: :agent, email: described_class::DEFAULT_OWNER_EMAIL)
  end
  let(:caio) { create(:user, account: account, role: :agent) }

  describe '.access_for' do
    it 'claims the configured default owner only for the owner email' do
      access = described_class.access_for(account: account, user: kelvin)

      expect(access[:allowed]).to be(true)
      expect(access[:owner]).to be(true)
      expect(account.reload.settings[described_class::OWNER_SETTING].to_i).to eq(kelvin.id)
    end

    it 'does not expose the assistant to another agent before sharing' do
      described_class.access_for(account: account, user: kelvin)

      access = described_class.access_for(account: account, user: caio)

      expect(access[:allowed]).to be(false)
      expect(access[:owner]).to be(false)
    end

    it 'allows the owner to share only with agents from the same account' do
      described_class.access_for(account: account, user: kelvin)

      described_class.update_shared_users!(account: account, user: kelvin, user_ids: [caio.id])

      expect(described_class.access_for(account: account, user: caio)[:allowed]).to be(true)
    end
  end
end
