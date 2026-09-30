require 'rails_helper'

RSpec.describe Conversations::ContactSearchService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Heloísa Martins', phone_number: '+5511965927865') }
  let!(:conversation) { create(:conversation, account: account, contact: contact, status: :resolved, custom_attributes: { rotta_pinned: true }) }

  def search(query)
    described_class.new(account.conversations, query).perform
  end

  it 'finds archived contacts without requiring a message or an exact accent' do
    expect(search('heloisa')).to include(conversation)
  end

  it 'suggests a name with a small typing error' do
    expect(search('Heloza')).to include(conversation)
  end

  it 'finds local, international and partial numbers' do
    ['11965927865', '+55 (11) 96592-7865', '1196'].each do |query|
      expect(search(query)).to include(conversation)
    end
  end

  it 'treats SQL wildcards literally' do
    expect(search('%_')).to be_empty
  end

  it 'never searches outside the supplied permission-filtered scope' do
    expect(described_class.new(account.conversations.where(id: -1), 'heloisa').perform).to be_empty
  end

  it 'keeps a pin-ordered result query valid without DISTINCT' do
    results = search('heloisa').order(Arel.sql("CASE WHEN conversations.custom_attributes ->> 'rotta_pinned' = 'true' THEN 0 ELSE 1 END"))
    expect(results.to_a).to include(conversation)
  end
end
