class Api::V1::Accounts::Captain::CopilotThreadsController < Api::V1::Accounts::BaseController
  include Captain::Copilot::ConversationAccess

  before_action :mark_conversation_ai_probe, only: :create
  before_action :ensure_message, only: :create
  before_action :ensure_accessible_conversation, only: :create

  def index
    @copilot_threads = copilot_threads_scope
                              .includes(:user, :assistant)
                              .order(created_at: :desc)
                              .page(permitted_params[:page] || 1)
                              .per(5)
  end

  def create
    Rails.logger.info("[ConversationAiProbe] create start request_type=#{params[:request_type]} conversation_id=#{params[:conversation_id]}")
    ActiveRecord::Base.transaction do
      @copilot_thread = if conversation_ai?
                          conversation = conversation_for_ai
                          Current.account.copilot_threads.find_or_create_by!(
                            conversation_id: conversation.id
                          ) do |thread|
                            thread.title = copilot_thread_params[:message]
                            thread.user = Current.user
                            thread.assistant = assistant unless conversation_ai?
                          end
                        else
                          Current.account.copilot_threads.create!(
                            title: copilot_thread_params[:message],
                            user: Current.user,
                            assistant: assistant
                          )
                        end
      Rails.logger.info("[ConversationAiProbe] thread ready id=#{@copilot_thread.id} conversation_id=#{@copilot_thread.conversation_id}")

      copilot_message = @copilot_thread.copilot_messages.create!(
        message_type: :user,
        message: user_message_payload
      )
      Rails.logger.info("[ConversationAiProbe] message ready id=#{copilot_message.id}")

      build_copilot_response(copilot_message)
      Rails.logger.info('[ConversationAiProbe] response enqueued')
    end
  rescue StandardError => e
    Rails.logger.error("[ConversationAiProbe] #{e.class}: #{e.message}\n#{e.backtrace.first(12).join("\n")}")
    return render json: { error: e.message, error_class: e.class.name }, status: :internal_server_error if conversation_ai?

    raise
  end

  private

  def build_copilot_response(copilot_message)
    if conversation_ai? || Current.account.usage_limits[:captain][:responses][:current_available].positive?
      enqueue_copilot_response(copilot_message)
    else
      copilot_message.copilot_thread.copilot_messages.create!(
        message_type: :assistant,
        message: { content: I18n.t('captain.copilot_limit') }
      )
    end
  end

  def enqueue_copilot_response(copilot_message)
    return enqueue_conversation_ai_response(copilot_message) if conversation_ai?
    return enqueue_reply_suggestion if reply_suggestion?

    copilot_message.enqueue_response_job(copilot_thread_params[:conversation_id], Current.user.id)
  end

  def enqueue_conversation_ai_response(copilot_message)
    ConversationAi::ResponseJob.perform_later(
      copilot_thread_id: @copilot_thread.id,
      conversation_id: @copilot_thread.conversation.display_id,
      user_id: Current.user.id,
      message: copilot_message.message['content']
    )
  end

  def enqueue_reply_suggestion
    Captain::Copilot::ReplySuggestionJob.perform_later(
      assistant: @copilot_thread.assistant,
      conversation_id: copilot_thread_params[:conversation_id],
      user_id: Current.user.id,
      copilot_thread_id: @copilot_thread.id
    )
  end

  def ensure_message
    return render_could_not_create_error(
      I18n.t('captain.copilot_message_required')
    ) if copilot_thread_params[:message].blank?
  end

  def ensure_accessible_conversation
    return unless reply_suggestion? || conversation_ai?

    return conversation_for_ai if conversation_ai?
    return if reply_suggestion? && accessible_conversation(
      account: Current.account,
      user: Current.user,
      display_id: copilot_thread_params[:conversation_id]
    ).present?

    raise ActiveRecord::RecordNotFound, 'Conversation not found'
  end

  def mark_conversation_ai_probe
    return unless params[:request_type] == 'conversation_ai'

    response.set_header('X-Rotta-Conversation-Ai-Code', 'e631735')
  end

  def conversation_for_ai
    display_id = copilot_thread_params[:conversation_id]
    raise ActiveRecord::RecordNotFound, 'Conversation not found' if display_id.blank?

    conversation_scope = Conversation.where(account_id: Current.account.id)
    conversation = conversation_scope.find_by(display_id: display_id) ||
                   conversation_scope.find_by(id: display_id)
    response.set_header(
      'X-Rotta-Conversation-Ai-Lookup',
      "account=#{Current.account.id};display=#{display_id};found=#{conversation.present?}"
    )
    raise ActiveRecord::RecordNotFound, 'Conversation not found' if conversation.blank?

    authorize conversation, :show?
    conversation
  end

  def reply_suggestion?
    copilot_thread_params[:request_type] == 'reply_suggestion'
  end

  def conversation_ai?
    copilot_thread_params[:request_type] == 'conversation_ai' ||
      (copilot_thread_params[:conversation_id].present? && copilot_thread_params[:assistant_id].blank?)
  end

  def copilot_threads_scope
    if permitted_params[:conversation_id].present?
      conversation = if permitted_params[:request_type] == 'conversation_ai'
                       display_id = permitted_params[:conversation_id]
                       conversation_scope = Conversation.where(account_id: Current.account.id)
                       found_conversation = conversation_scope.find_by(display_id: display_id) ||
                                             conversation_scope.find_by(id: display_id)
                       raise ActiveRecord::RecordNotFound if found_conversation.blank?

                       authorize found_conversation, :show?
                       found_conversation
                     else
                       accessible_conversation(
                         account: Current.account,
                         user: Current.user,
                         display_id: permitted_params[:conversation_id]
                       )
                     end
      raise ActiveRecord::RecordNotFound if conversation.blank?

      Current.account.copilot_threads.where(conversation_id: conversation.id)
    else
      Current.account.copilot_threads.where(user_id: Current.user.id)
    end
  end

  def assistant
    Current.account.captain_assistants.find(copilot_thread_params[:assistant_id])
  end

  def user_message_payload
    return { content: copilot_thread_params[:message] } unless conversation_ai?

    {
      content: copilot_thread_params[:message],
      author_id: Current.user.id,
      author_name: Current.user.name,
      author_email: Current.user.email
    }
  end

  def copilot_thread_params
    params.permit(:message, :assistant_id, :conversation_id, :request_type)
  end

  def permitted_params
    params.permit(:page, :conversation_id, :request_type)
  end
end
