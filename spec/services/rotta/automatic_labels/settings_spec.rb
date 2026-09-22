require 'rails_helper'

RSpec.describe Rotta::AutomaticLabels::Settings do
  let(:account) { create(:account) }

  it 'defaults every automation to disabled' do
    expect(described_class.for(account)).to eq(
      'first_contact' => false,
      'kelvin' => false,
      'caio_attention' => false
    )
  end

  it 'updates only known keys' do
    result = described_class.update(account, first_contact: true, unknown: true)

    expect(result['first_contact']).to be(true)
    expect(account.reload.rotta_automatic_labels).not_to have_key('unknown')
  end
end
