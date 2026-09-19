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

    it 'finds a conversation by display id and exposes its newest message as authoritative context' do
      conversation = create(:conversation, account: account)
      create(
        :message,
        account: account,
        inbox: conversation.inbox,
        conversation: conversation,
        message_type: :outgoing,
        content: 'contexto antigo'
      )
      newest_message = create(
        :message,
        account: account,
        inbox: conversation.inbox,
        conversation: conversation,
        message_type: :outgoing,
        content: 'contexto atualizado'
      )

      result = described_class.new(
        account: account,
        question: "qual foi a mensagem mais recente da conversa #{conversation.display_id}?"
      ).call

      expect(result[:cards].pluck(:conversation_id)).to eq([conversation.display_id])
      expect(result[:cards].first[:last_message]).to eq('contexto atualizado')
      expect(result[:cards].first[:last_activity_at]).to eq(conversation.last_activity_at&.iso8601)
      expect(result[:cards].first[:evidence]).to include(
        content: 'contexto atualizado',
        created_at: newest_message.created_at.iso8601,
        reason: 'mensagem mais recente'
      )
      expect(result[:cards].first[:recent_history].last).to include(
        content: 'contexto atualizado',
        created_at: newest_message.created_at.iso8601
      )
    end
  end
end
