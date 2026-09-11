class ConversationAi::ResponseJob < ApplicationJob
  queue_as :default

  def perform(copilot_thread_id:, user_id:, message:, conversation_id: nil)
    thread = CopilotThread.includes(:account, :conversation).find(copilot_thread_id)
    conversation = thread.conversation
    raise ActiveRecord::RecordNotFound,
          'Conversation not found for Copilot thread' if conversation.blank?

    user = thread.account.users.find(user_id)
    request_id = SecureRandom.uuid
    payload = ConversationAi::ContextBuilder.new(
      conversation: conversation,
      user: user,
      question: message,
      request_id: request_id,
      copilot_thread_id: thread.id
    ).payload

    request_body = payload.to_json
    response = HTTParty.post(
      webhook_url,
      headers: webhook_headers,
      body: request_body,
      timeout: 120
    )

    raise "Pergunte para IA recusou a solicitação (HTTP #{response.code})" unless response.success?

    body = response.parsed_response
    validate_response_metadata!(
      body,
      request_id: request_id,
      copilot_thread: thread,
      conversation: conversation
    )
    answer = body.is_a?(Hash) ? body['answer'].to_s.strip : ''
    raise 'Pergunte para IA retornou uma resposta vazia' if answer.blank?

    thread.copilot_messages.create!(
      message_type: :assistant,
      message: {
        content: answer,
        assistant: 'Pergunte para IA',
        model: 'deepseek/deepseek-v4-flash-0731'
      }
    )
  rescue StandardError => e
    Rails.logger.error("[ConversationAi] #{e.class}: #{e.message}")
    thread&.copilot_messages&.create!(
      message_type: :assistant,
      message: { content: I18n.t('captain.conversation_ai.failed') }
    )
  end

  private

  def webhook_url
    ENV.fetch(
      'ROTTA_CONVERSATION_AI_WEBHOOK_URL',
      'https://saas.via-cargo.com/webhook/rotta-conversation-ai-v1'
    )
  end

  def webhook_headers
    secret = ENV.fetch('ROTTA_CONVERSATION_AI_WEBHOOK_SECRET')
    raise 'ROTTA_CONVERSATION_AI_WEBHOOK_SECRET não configurado' if secret.blank?

    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'X-Rotta-Conversation-AI-Secret' => secret
    }
  end

  def validate_response_metadata!(body, request_id:, copilot_thread:, conversation:)
    raise 'Pergunte para IA retornou um envelope inválido' unless body.is_a?(Hash)

    expected = {
      'request_id' => request_id,
      'copilot_thread_id' => copilot_thread.id,
      'conversation_id' => conversation.display_id,
      'account_id' => conversation.account_id
    }
    mismatched = expected.find do |key, value|
      body[key].blank? || body[key].to_s != value.to_s
    end
    return if mismatched.blank?

    key, value = mismatched
    raise "Pergunte para IA retornou vínculo inválido (#{key}=#{value})"
  end
end
