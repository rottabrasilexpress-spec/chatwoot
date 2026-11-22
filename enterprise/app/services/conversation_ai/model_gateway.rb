module ConversationAi::ModelGateway
  private

  def specialist_client(thread, conversation)
    lambda do |messages|
      request_id = SecureRandom.uuid
      payload = {
        kind: 'read_only_specialist',
        request_id: request_id,
        account_id: thread.account_id,
        conversation_id: conversation.display_id,
        copilot_thread_id: thread.id,
        system_prompt: messages.first.fetch(:content),
        prompt: messages.last.fetch(:content)
      }
      webhook_answer(payload.to_json, request_id, thread, conversation, timeout: 38)
    end
  end

  def webhook_answer(request_body, request_id, thread, conversation, timeout: 120)
    response = HTTParty.post(webhook_url, headers: webhook_headers, body: request_body, timeout: timeout)
    raise "Pergunte para IA recusou a solicitação (HTTP #{response.code})" unless response.success?

    body = response.parsed_response
    validate_response_metadata!(body, request_id: request_id, copilot_thread: thread, conversation: conversation)
    provider_status = body['provider_status']
    raise "Modelo recusou a consulta (HTTP #{provider_status.to_i})" if provider_status && !(200..299).cover?(provider_status.to_i)

    body['answer']
  end

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
