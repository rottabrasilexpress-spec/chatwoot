require 'rails_helper'

RSpec.describe Rotta::AutomaticLabels::Processor do
  let(:account) { create(:account, rotta_automatic_labels: settings) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:settings) { { first_contact: true, kelvin: true, caio_attention: true } }

  before do
    %w[Primeiro\ contato KELVIN Caio\ Atenção Orçamento\ feito].each do |title|
      create(:label, account: account, title: title)
    end
  end

  it 'applies Primeiro contato only on the first inbound message' do
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :incoming, content_type: :text, content: 'Olá')

    described_class.new(message).perform
    expect(conversation.reload.label_list).to include('Primeiro contato')

    second = create(:message, account: account, inbox: inbox, conversation: conversation,
                              message_type: :incoming, content_type: :text, content: 'Mais uma mensagem')
    described_class.new(second).perform
    expect(conversation.reload.label_list.count('Primeiro contato')).to eq(1)
  end

  it 'does not reapply Primeiro contato in a later conversation with the same contact' do
    prior = create(:message, account: account, inbox: inbox, conversation: conversation,
                             message_type: :incoming, content_type: :text, content: 'Contato anterior')
    described_class.new(prior).perform
    conversation.update_labels([])
    next_conversation = create(:conversation, account: account, inbox: inbox, contact: conversation.contact)
    message = create(:message, account: account, inbox: inbox, conversation: next_conversation,
                               sender: conversation.contact, message_type: :incoming,
                               content_type: :text, content: 'Nova conversa')

    described_class.new(message).perform

    expect(next_conversation.reload.label_list).to be_empty
  end

  it 'adds KELVIN before removing Primeiro contato for a complete pre-budget block' do
    conversation.update_labels(['Primeiro contato'])
    content = <<~TEXT
      PRÉ-ORÇAMENTO
      ORIGEM: São Paulo
      DESTINO: Curitiba
      INVENTÁRIO: cama e geladeira
      EQUIPE: 4 AJUDANTES para CARGA e DESCARGA
      SERVIÇOS: MONTAGEM
      PAGAMENTO: 60% na coleta e 40% na entrega
    TEXT
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :outgoing, content_type: :text, content: content)

    described_class.new(message).perform

    expect(conversation.reload.label_list).to include('KELVIN')
    expect(conversation.label_list).not_to include('Primeiro contato')
  end

  it 'only applies Caio Atenção inside the budget trail and never removes it automatically' do
    conversation.update_labels(['Orçamento feito'])
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :incoming, content_type: :text,
                               content: 'Quero fechar, preciso falar com um atendente')

    2.times { described_class.new(message).perform }

    expect(conversation.reload.label_list).to include('Caio Atenção')
    expect(conversation.label_list.count('Caio Atenção')).to eq(1)
    expect(account.rotta_automatic_label_logs.where(event_key: "#{message.id}:caio_attention").count).to eq(1)
  end

  it 'checks Caio Atenção trail eligibility while holding the conversation lock' do
    account.update!(rotta_automatic_labels: { caio_attention: true })
    conversation.update_labels(['Primeiro contato'])
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :incoming, content_type: :text,
                               content: 'Quero falar com um atendente')
    processor = described_class.new(message)
    lock_held = false

    allow(conversation).to receive(:with_lock).and_wrap_original do |original, &block|
      lock_held = true
      begin
        original.call(&block)
      ensure
        lock_held = false
      end
    end
    allow(processor).to receive(:canonical_labels) do
      expect(lock_held).to be(true)
      ['primeiro-contato']
    end

    processor.perform

    expect(conversation.reload.label_list).not_to include('Caio Atenção')
  end

  it 'does nothing while every automation is disabled' do
    account.update!(rotta_automatic_labels: {})
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :incoming, content_type: :text, content: 'Olá')

    described_class.new(message).perform

    expect(conversation.reload.label_list).to be_empty
    expect(account.rotta_automatic_label_logs).to be_empty
  end
end
