class ConversationAi::ResponseJob < ApplicationJob
  include ConversationAi::ModelGateway

  queue_as :default
  self.enqueue_after_transaction_commit = :always

  def perform(copilot_thread_id:, user_id:, message:, conversation_id: nil, request_message_id: nil)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    thread = CopilotThread.includes(:account, :private_conversation).find(copilot_thread_id)
    conversation = thread.private_conversation
    raise ActiveRecord::RecordNotFound,
          'Conversation not found for Copilot thread' if conversation.blank?

    user = thread.account.users.find(user_id)
    return unless user.id == thread.user_id
    return unless ConversationPolicy.new(
      { user: user, account: thread.account, account_user: thread.account.account_users.find_by!(user: user) }, conversation
    ).show?

    request_record = thread.copilot_messages.find_by(id: request_message_id, message_type: :user) if request_message_id
    request_reply = thread.copilot_messages.where(message_type: :assistant).where("message->>'in_reply_to' = ?", request_message_id.to_s)
    return if request_message_id && (request_record.blank? || request_reply.exists?)

    mode = ConversationAi::Consultation.resolve_mode(request_record&.message&.fetch('conversation_ai_mode', nil), message)
    request_id = SecureRandom.uuid
    context = ConversationAi::ContextBuilder.new(
      conversation: conversation,
      user: user,
      question: message,
      request_id: request_id,
      copilot_thread_id: thread.id,
      request_message_id: request_message_id,
      detailed: mode.present?
    )

    request_body = mode ? nil : context.payload.to_json
    context_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    answer = if mode
               client = specialist_client(thread, conversation)
               ConversationAi::Consultation.new(context: context, mode: mode, client: client).call
             else
               ConversationAi::Consultation.envelope(webhook_answer(request_body, request_id, thread, conversation))
             end
    raise 'Pergunte para IA retornou uma resposta vazia' if answer[:content].blank?

    save_response(thread, request_reply, request_message_id, answer)
    Rails.logger.info(
      "[ConversationAi::Timing] request_id=#{request_id} thread_id=#{thread.id} " \
      "mode=#{mode || 'quick'} context_ms=#{context_ms} " \
      "total_ms=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round}"
    )
  rescue StandardError => e
    raise if thread.nil?

    provider_status = e.message[/\bHTTP (\d{3})\b/, 1]
    Rails.logger.error("[ConversationAi] error=#{e.class} status=#{provider_status || '-'} request_id=#{request_id}")
    return if request_reply.nil?

    save_response(thread, request_reply, request_message_id, {
                    content: ConversationAi::Consultation.failure_message,
                    consultation_status: 'failed'
                  })
  end

  private

  def save_response(thread, request_reply, request_message_id, answer)
    thread.with_lock do
      return if request_message_id && request_reply.exists?

      thread.copilot_messages.create!(
        message_type: :assistant,
        message: answer.merge(
          assistant: 'Pergunte para IA', model: GlobalAiAssistant::ProviderConfig::MODEL, in_reply_to: request_message_id
        ).compact
      )
    end
  end
end
