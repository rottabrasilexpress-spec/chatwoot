require 'rails_helper'

RSpec.describe Rotta::AutomaticLabels::Processor do
  let(:account) { create(:account, rotta_automatic_labels: settings) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:settings) { { first_contact: true, kelvin: true, caio_attention: true } }

  before do
    %w[primeiro-contato kelvin caio-atencao orcamento-feito].each do |title|
      create(:label, account: account, title: title)
    end
  end

  def create_prior_inbound_message
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                     message_type: :incoming, content_type: :text, content: 'Mensagem anterior')
  end

  it 'applies Primeiro contato only on the first inbound message' do
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content_type: :text, content: 'Olá')
    conversation.reload
    message.reload

    described_class.new(message).perform
    expect(conversation.reload.label_list).to include('primeiro-contato')

    second = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                              message_type: :incoming, content_type: :text, content: 'Mais uma mensagem')
    described_class.new(second).perform
    expect(conversation.reload.label_list.count('primeiro-contato')).to eq(1)
  end

  it 'does not reapply Primeiro contato in a later conversation with the same contact' do
    prior = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                             message_type: :incoming, content_type: :text, content: 'Contato anterior')
    conversation.reload
    prior.reload
    described_class.new(prior).perform
    conversation.update_labels([])
    next_conversation = create(:conversation, account: account, inbox: inbox, contact: conversation.contact)
    message = create(:message, account: account, inbox: inbox, conversation: next_conversation,
                               sender: conversation.contact, message_type: :incoming,
                               content_type: :text, content: 'Nova conversa')
    message.reload

    described_class.new(message).perform

    expect(next_conversation.reload.label_list).to be_empty
  end

  it 'adds KELVIN before removing Primeiro contato for a complete pre-budget block' do
    conversation.update_labels(['primeiro-contato'])
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

    expect(conversation.reload.label_list).to include('kelvin')
    expect(conversation.label_list).not_to include('primeiro-contato')
  end

  it 'only applies Caio Atenção inside the budget trail and never removes it automatically' do
    conversation.update_labels(['orcamento-feito'])
    create_prior_inbound_message
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content_type: :text,
                               content: 'Quero fechar, preciso falar com um atendente')
    expect(Rotta::AutomaticLabels::HumanNeedClassifier).not_to receive(:new)

    2.times { described_class.new(message).perform }

    expect(conversation.reload.label_list).to include('caio-atencao')
    expect(conversation.label_list.count('caio-atencao')).to eq(1)
    expect(account.rotta_automatic_label_logs.where(event_key: "#{message.id}:caio_attention").count).to eq(1)
  end

  it 'does not call the LLM for messages without a human-need signal' do
    conversation.update_labels(['orcamento-feito'])
    message = create(:message, account: account, inbox: inbox, conversation: conversation,
                               message_type: :incoming, content_type: :text, content: 'Obrigado, entendido')

    expect(Rotta::AutomaticLabels::HumanNeedClassifier).not_to receive(:new)

    described_class.new(message).perform
  end

  it 'keeps Caio Atenção off when the LLM is uncertain or returns false' do
    conversation.update_labels(['orcamento-feito'])
    create_prior_inbound_message
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content_type: :text,
                               content: 'Qual é o valor aproximado?')
    allow(Rotta::AutomaticLabels::HumanNeedClassifier).to receive(:new).and_return(
      instance_double(Rotta::AutomaticLabels::HumanNeedClassifier,
                      call: Rotta::AutomaticLabels::HumanNeedClassifier::Decision.new(
                        needs_human: false, confidence: 0.61, reason: 'pergunta que a IA pode responder'
                      ))
    )

    described_class.new(message).perform

    expect(conversation.reload.label_list).not_to include('caio-atencao')
    expect(account.rotta_automatic_label_logs.find_by(event_key: "#{message.id}:caio_attention")).to have_attributes(
      status: 'skipped'
    )
  end

  it 'calls the LLM only for an ambiguous human-need signal' do
    conversation.update_labels(['orcamento-feito'])
    create_prior_inbound_message
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content_type: :text,
                               content: 'Qual é o valor aproximado?')
    decision = Rotta::AutomaticLabels::HumanNeedClassifier::Decision.new(
      needs_human: true, confidence: 0.91, reason: 'contexto exige confirmação humana'
    )
    classifier = instance_double(Rotta::AutomaticLabels::HumanNeedClassifier, call: decision)
    expect(Rotta::AutomaticLabels::HumanNeedClassifier).to receive(:new).and_return(classifier)

    described_class.new(message).perform

    expect(conversation.reload.label_list).to include('caio-atencao')
  end

  it 'uses conversation context for an interested customer asking for a vehicle detail that needs human confirmation' do
    conversation.update_labels(['orcamento-feito'])
    conversation_context_time = Time.current.change(usec: 0)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                     message_type: :incoming, content_type: :text,
                     content: 'Escolhi a opção 1, transporte mais serviços', created_at: conversation_context_time - 6.minutes)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, content_type: :text,
                     content: 'Entendi, vou seguir com essa opção.', created_at: conversation_context_time - 5.minutes)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                     message_type: :incoming, content_type: :text,
                     content: 'Inclui os ajudantes?', created_at: conversation_context_time - 4.minutes)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, content_type: :text,
                     content: 'O setor responsável confirma o veículo e o valor final.', created_at: conversation_context_time - 3.minutes)
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                     message_type: :incoming, content_type: :text,
                     content: 'O caminhão é bem grande? Os móveis são grandes.', created_at: conversation_context_time - 2.minutes)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, content_type: :text,
                     content: 'Vou confirmar o tamanho do veículo com a equipe.', created_at: conversation_context_time - 1.minute)
    message = create(:message, account: account, inbox: inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content_type: :text,
                               content: 'Meu marido está pedindo se você pode mandar o tamanho do caminhão?')
    conversation.reload
    message.reload
    decision = Rotta::AutomaticLabels::HumanNeedClassifier::Decision.new(
      needs_human: true, confidence: 0.94, reason: 'detalhe do veículo depende de confirmação operacional'
    )
    classifier = instance_double(Rotta::AutomaticLabels::HumanNeedClassifier)

    expect(Rotta::AutomaticLabels::HumanNeedClassifier).to receive(:new).and_return(classifier)
    expect(classifier).to receive(:call) do |context|
      expect(context[:last_message]).to eq(message.content)
      expect(context[:recent_messages].map { |item| item[:content] }).to include(
        'Escolhi a opção 1, transporte mais serviços', 'O setor responsável confirma o veículo e o valor final.'
      )
      expect(context[:recent_messages].size).to eq(6)
      expect(context[:recent_messages].first[:content]).to eq('Escolhi a opção 1, transporte mais serviços')
      expect(context[:recent_messages].last[:content]).to eq('Vou confirmar o tamanho do veículo com a equipe.')
      decision
    end

    described_class.new(message).perform

    expect(conversation.reload.label_list).to include('orcamento-feito', 'caio-atencao')
  end

  it 'checks Caio Atenção trail eligibility while holding the conversation lock' do
    account.update!(rotta_automatic_labels: { caio_attention: true })
    conversation.update_labels(['primeiro-contato'])
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

    expect(conversation.reload.label_list).not_to include('caio-atencao')
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
