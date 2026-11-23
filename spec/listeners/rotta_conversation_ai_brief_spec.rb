require 'rails_helper'

RSpec.describe RottaAutomaticLabelListener, type: :request do
  let(:conversation) { create(:conversation) }
  let(:account) { conversation.account }
  let(:kelvin) { create(:user, account: account, role: :administrator) }
  let(:caio) { create(:user, account: account, role: :administrator) }
  let(:job) { ConversationAi::AutomaticBriefJob }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/captain/conversation_ai/automatic_brief" }
  let(:webhook_url) { 'https://rotta.example.test/conversation-ai' }
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
                      ROTTA_CONVERSATION_AI_WEBHOOK_URL: webhook_url,
                      ROTTA_CONVERSATION_AI_WEBHOOK_SECRET: 'test-only-secret',
                      ROTTA_CONVERSATION_AI_AUTOMATIC_BRIEF: 'true' do
      example.run
    end
  end

  it 'queues a private review after a responsible label is added' do
    expect { described_class.instance.conversation_updated(event) }.to have_enqueued_job(job)
  end

  it 'recovers a missing review for an existing Caio label exactly once, only for Kelvin' do
    incoming
    conversation.update_labels(['caio-atencao'])
    params = { conversation_id: conversation.display_id }
    caio_headers = caio.create_new_auth_token
    kelvin_headers = kelvin.create_new_auth_token
    expect { get endpoint, params: params, headers: caio_headers }.not_to have_enqueued_job(job)
    expect(response).to have_http_status(:not_found)

    gateway = stub_request(:post, webhook_url).to_return do |request|
      payload = JSON.parse(request.body)
      answer = {
        kind: 'review', draft: 'Vou confirmar a previsão.',
        topics: [{ request: 'Prazo', answer: 'Confirmar com a operação', message_id: incoming.id }]
      }.to_json
      envelope = payload.slice('account_id', 'conversation_id', 'copilot_thread_id', 'request_id').merge('answer' => answer)
      { status: 200, body: envelope.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    expect do
      2.times { get endpoint, params: params, headers: kelvin_headers }
    end.to have_enqueued_job(job).exactly(:once)
    expect(response).to have_http_status(:no_content)

    labels = conversation.reload.label_list.to_a
    expect { perform_enqueued_jobs(only: job) }.not_to change(Message, :count)
    expect(conversation.reload.label_list.to_a).to eq(labels)
    expect(gateway).to have_been_requested.once
    get endpoint, params: params, headers: kelvin_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('result', 'topics', 0, 'request')).to eq('Prazo')
  end

  it 'uses one model call for a repeated event and returns both topics only to Kelvin' do
    incoming
    conversation.update_labels(%w[orcamento-feito kelvin caio-atencao])
    expect(GlobalAiAssistant::OpenRouterClient).not_to receive(:new)
    gateway = stub_request(:post, webhook_url).with(headers: { 'X-Rotta-Conversation-AI-Secret' => 'test-only-secret' }).to_return do |request|
      payload = JSON.parse(request.body)
      expect(payload).to include('kind' => 'read_only_specialist', 'conversation_id' => conversation.display_id, 'account_id' => account.id)
      expect(CopilotThread.find(payload.fetch('copilot_thread_id')).user_id).to eq(kelvin.id)
      answer = {
        kind: 'review', draft: 'O valor será [NOVO VALOR].',
        topics: [
          { request: 'Incluir sofá', answer: 'Recalcular o orçamento', message_id: incoming.id },
          { request: 'Prazo de entrega', answer: 'Confirmar prazo', message_id: incoming.id }
        ]
      }.to_json
      envelope = payload.slice('account_id', 'conversation_id', 'copilot_thread_id', 'request_id').merge('answer' => answer, 'provider_status' => 200)
      { status: 200, body: envelope.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    targets = %w[caio-atencao kelvin]
    timestamp = Time.current.utc.iso8601(6)
    expect do
      2.times { job.perform_now(conversation.id, timestamp, %w[orcamento-feito], targets) }
    end.not_to change(Message, :count)
    expect(gateway).to have_been_requested.once

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
    expect do
      get endpoint, params: { conversation_id: conversation.display_id }, headers: kelvin.create_new_auth_token
    end.not_to have_enqueued_job(job)
    expect(response).to have_http_status(:no_content)
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
    expect do
      job.perform_now(conversation.id, Time.current.utc.iso8601(6), ['caio-atencao'], [])
    end.to have_enqueued_job(ActionCableBroadcastJob).with(
      [kelvin.pubsub_token], 'conversation.ai_brief_updated', { account_id: account.id, conversation_id: conversation.display_id }
    )
    expect(ConversationAiBrief.find_by!(conversation: conversation).state).to eq('cancelled')
  end

  it 'keeps label updates isolated when disabled' do
    with_modified_env ROTTA_CONVERSATION_AI_AUTOMATIC_BRIEF: '' do
      expect { described_class.instance.conversation_updated(event) }.not_to have_enqueued_job(job)
    end
  end
end
