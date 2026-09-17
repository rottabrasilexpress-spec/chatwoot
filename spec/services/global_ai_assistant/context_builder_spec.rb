require 'rails_helper'

RSpec.describe GlobalAiAssistant::ContextBuilder do
  describe '#call' do
    let(:account) { create(:account) }

    it 'does not use recent unrelated conversations when no evidence matches' do
      create(:conversation, account: account, contact: create(:contact, account: account, name: 'Cliente sem relação'))

      result = described_class.new(
        account: account,
        question: 'qual cliente tem o telefone 00000000000?'
      ).call

      expect(result[:cards]).to be_empty
      expect(result[:source_messages]).to be_empty
    end

    it 'finds a contact phone embedded in a natural-language question' do
      matching_contact = create(
        :contact,
        account: account,
        name: 'Kelvin Martins',
        phone_number: '+5511965927865'
      )
      matching_conversation = create(:conversation, account: account, contact: matching_contact)
      create(:conversation, account: account, contact: create(:contact, account: account, name: 'Outro cliente'))

      result = described_class.new(
        account: account,
        question: 'onde está o cliente do telefone 11 96592-7865?'
      ).call

      expect(result[:cards].pluck(:conversation_id)).to eq([matching_conversation.display_id])
    end
  end
end
