require 'rails_helper'

RSpec.describe RottaAutomaticLabelListener, type: :request do
  let(:conversation) { create(:conversation) }
  let(:account) { conversation.account }
  let(:kelvin) { create(:user, account: account, role: :administrator) }
  let(:caio) { create(:user, account: account, role: :administrator) }
  let(:job) { ConversationAi::AutomaticBriefJob }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/captain/conversation_ai/automatic_brief" }
  let(:client) { instance_double(GlobalAiAssistant::OpenRouterClient) }
  let(:incoming) do
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     sender: conversation.contact, message_type: :incoming, content: 'Adicione um sofá. Qual o prazo de entrega?')
  end
  let(:event) do
    Events::Base.new('conversation.updated', Time.current, {
                       conversation: conversation,
                       changed_attributes: { 'label_list' => [%w[orcamento-feito], %w[orcamento-feito kelvin]] }
                     })
  end

  around do |example|
    with_modified_env ROTTABRASIL_CHATWOOT_ACCOUNT_ID: account.id.to_s,
                      ROTTABRASIL_ATTENTION_REQUESTER_USER_ID: kelvin.id.to_s,
                      ROTTABRASIL_CAIO_USER_ID: caio.id.to_s,
                      ROTTA_CONVERSATION_AI_AUTOMATIC_BRIEF: 'true' do
      example.run
    end
  end

  it 'queues a private review after a responsible label is added' do
    expect { described_class.instance.conversation_updated(event) }.to have_enqueued_job(job)
  end

  it 'uses one model call for a repeated event and returns both topics only to Kelvin' do
    incoming
    conversation.update_labels(%w[orcamento-feito kelvin caio-atencao])
    allow(GlobalAiAssistant::OpenRouterClient).to receive(:new).and_return(client)
    expect(client).to receive(:call).once.and_return(
      {
        kind: 'review', draft: 'O valor será [NOVO VALOR].',
        topics: [
          { request: 'Incluir sofá', answer: 'Recalcular o orçamento', message_id: incoming.id },
          { request: 'Prazo de entrega', answer: 'Confirmar prazo', message_id: incoming.id }
        ]
      }.to_json
    )
    targets = %w[caio-atencao kelvin]
    timestamp = Time.current.utc.iso8601(6)
    expect do
      2.times { job.perform_now(conversation.id, timestamp, %w[orcamento-feito], targets) }
    end.not_to change(Message, :count)

    get endpoint, params: { conversation_id: conversation.display_id }, headers: kelvin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('result', 'topics').pluck('request')).to eq(['Incluir sofá', 'Prazo de entrega'])

    get endpoint, params: { conversation_id: conversation.display_id }, headers: caio.create_new_auth_token
    expect(response).to have_http_status(:not_found)
  end

  it 'skips the automatic Kelvin transition for a first quote before calling the model' do
    incoming
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     message_type: :outgoing, content: "PRÉ-ORÇAMENTO\nRota: origem ao destino\nInventário: sofá")
    conversation.update_labels(%w[kelvin])
    expect(GlobalAiAssistant::OpenRouterClient).not_to receive(:new)

    job.perform_now(conversation.id, Time.current.utc.iso8601(6), ['primeiro-contato'], ['kelvin'])
    expect(ConversationAiBrief.find_by!(conversation: conversation).state).to eq('skipped')
  end

  it 'does not show stale or removed assignments' do
    conversation.update_labels(['caio-atencao'])
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     sender: conversation.contact, message_type: :incoming, content: 'Qual caminhão?')
    ConversationAiBrief.create!(
      conversation: conversation, user: kelvin, triggered_at: 1.minute.ago, state: 'ready',
      labels: ['caio-atencao'], result: { draft: 'Rascunho antigo' }
    )
    get endpoint, params: { conversation_id: conversation.display_id }, headers: kelvin.create_new_auth_token
    expect(response).to have_http_status(:no_content)

    conversation.update_labels([])
    expect(GlobalAiAssistant::OpenRouterClient).not_to receive(:new)
    job.perform_now(conversation.id, Time.current.utc.iso8601(6), ['caio-atencao'], [])
    expect(ConversationAiBrief.find_by!(conversation: conversation).state).to eq('cancelled')
  end

  it 'keeps label updates isolated when disabled' do
    with_modified_env ROTTA_CONVERSATION_AI_AUTOMATIC_BRIEF: '' do
      expect { described_class.instance.conversation_updated(event) }.not_to have_enqueued_job(job)
    end
  end
end
