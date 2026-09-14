require 'rails_helper'

RSpec.describe ConversationAi::ProfileContextBuilder do
  def message(id:, content:, created_at:, private_message: false, sender_type: 'Contact')
    instance_double(
      Message,
      id: id,
      content: content,
      created_at: created_at,
      private?: private_message,
      sender_type: sender_type
    )
  end

  let(:conversation) { instance_double(Conversation) }

  it 'bounds the profile context and prioritises operational evidence' do
    messages = 12.times.map do |index|
      message(
        id: index + 1,
        content: "FILLER-#{index} #{'texto antigo sem dados operacionais. ' * 100}",
        created_at: (3.days - index.hours).ago
      )
    end
    messages += [
      message(
        id: 13,
        content: 'ORIGEM: Guarulhos, SP\nDESTINO: Salvador, BA\nCOLETA: 20 a 30 dias',
        created_at: 2.days.ago
      ),
      message(id: 14, content: 'Última confirmação do cliente.', created_at: 1.hour.ago)
    ]

    result = described_class.new(conversation: conversation, messages: messages).call

    expect(result[:messages].sum { |entry| entry[:content].length }).to be <= described_class::MAX_CONTEXT_CHARACTERS
    expect(result[:messages].map { |entry| entry[:content] }.join).to include('ORIGEM: Guarulhos')
    expect(result[:messages].map { |entry| entry[:content] }.join).to include('Última confirmação')
    expect(result[:messages].map { |entry| entry[:content] }.join).not_to include('FILLER-0')
    expect(result[:metrics]).to include(message_count: 14, truncated: true)
  end

  it 'uses text content only and keeps private text as auditable evidence' do
    messages = [
      message(id: 1, content: nil, created_at: 1.hour.ago),
      message(id: 2, content: 'Nota interna com o valor confirmado.', created_at: 2.hours.ago, private_message: true),
      message(id: 3, content: 'Texto público.', created_at: 3.hours.ago)
    ]

    result = described_class.new(conversation: conversation, messages: messages).call
    text = result[:messages].map { |entry| entry[:content] }.join

    expect(text).to include('Nota interna')
    expect(text).to include('Texto público')
    expect(result[:metrics]).to include(message_count: 2, selected_message_count: 2, truncated: false)
  end
end
