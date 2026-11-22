require 'rails_helper'

RSpec.describe ConversationAi::ContextBuilder do
  let(:conversation) do
    instance_double(
      Conversation,
      id: 88,
      account_id: 1,
      display_id: 2165,
      label_list: [],
      contact: instance_double(Contact, to_llm_text: 'Nome: Kelvin')
    )
  end
  let(:user) { instance_double(User, id: 17, name: 'Caio', email: 'caio@example.com') }

  it 'builds a per-agent payload with dated messages from the selected conversation' do
    reader = instance_double(ConversationAi::ProfileContextBuilder, call: {
                                messages: [
                                  { id: 42, created_at: '2026-11-17T15:00:00-03:00', sender: 'agente humano', content: 'O valor foi R$ 500.' },
                                  { id: 43, created_at: '2026-11-17T15:01:00-03:00', sender: 'cliente', content: 'Tenho mais dois móveis.' }
                                ],
                                metrics: { truncated: false }
                              })
    allow(ConversationAi::ProfileContextBuilder).to receive(:new).and_return(reader)
    expect(CopilotThread).to receive(:find_by).with(id: 44, account_id: 1, private_conversation_id: 88, user_id: 17).and_return(nil)
    payload = described_class.new(
      conversation: conversation,
      user: user,
      question: 'Quantos móveis foram acrescentados?',
      request_id: 'req-123',
      copilot_thread_id: 44
    ).payload

    expect(payload).to include(
      account_id: 1,
      conversation_id: 2165,
      session_key: 'chatwoot:conversation-ai:private:1:2165:17',
      question: 'Quantos móveis foram acrescentados?',
      request_id: 'req-123',
      copilot_thread_id: 44,
      agent: { id: 17, name: 'Caio', email: 'caio@example.com' }
    )
    expect(payload[:prompt]).to include('agente humano:', 'cliente:', 'O valor foi R$ 500.', 'Tenho mais dois móveis.')
    expect(payload[:prompt]).to include('CONSULTAS PRIVADAS ANTERIORES DESTE AGENTE')
    expect(payload[:prompt]).to include('Responda em português do Brasil')
  end
end
