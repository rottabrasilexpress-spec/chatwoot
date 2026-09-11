require 'rails_helper'

RSpec.describe ConversationAi::ContextBuilder do
  let(:conversation) do
    instance_double(
      Conversation,
      account_id: 1,
      display_id: 2165,
      label_list: [],
      contact: instance_double(Contact, to_llm_text: 'Nome: Kelvin'),
      inbox: instance_double(Inbox, name: 'WhatsApp Rotta'),
      to_llm_text: "Conversation ID: #2165\nSupport Agent: O valor foi R$ 500.\nUser: Tenho mais dois móveis.\n"
    )
  end
  let(:user) { instance_double(User, id: 17, name: 'Caio', email: 'caio@example.com') }

  it 'builds a complete, shared, agent-audited conversation payload' do
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
      session_key: 'chatwoot:conversation-ai:1:2165',
      question: 'Quantos móveis foram acrescentados?',
      request_id: 'req-123',
      copilot_thread_id: 44,
      agent: { id: 17, name: 'Caio', email: 'caio@example.com' }
    )
    expect(payload[:prompt]).to include('Support Agent:', 'User:', 'O valor foi R$ 500.', 'Tenho mais dois móveis.')
    expect(payload[:prompt]).to include('Não invente fatos')
    expect(payload[:prompt]).to include('Responda em português do Brasil, como assistente interno')
  end
end
