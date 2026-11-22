class Api::V1::Accounts::Captain::CopilotMessagesController < Api::V1::Accounts::BaseController
  include Captain::Copilot::ConversationAccess

  before_action :set_copilot_thread

  def index
    scope = @copilot_thread.copilot_messages
    after_id = permitted_params[:after_id].to_i
    before_id = permitted_params[:before_id].to_i
    if @copilot_thread.private_conversation_id.present? && !after_id.positive?
      scope = scope.where('id < ?', before_id) if before_id.positive?
      @copilot_messages = scope.includes(copilot_thread: [:user, :private_conversation]).order(id: :desc).page(1).per(40)
      return
    end
    scope = scope.where('id >= ?', after_id) if after_id.positive?
    @copilot_messages = scope
                        .includes(:copilot_thread)
                        .order(created_at: :asc)
                        .page(permitted_params[:page] || 1)
                        .per(1000)
  end

  def create
    @copilot_message = @copilot_thread.copilot_messages.create!(
      message: {
        content: params[:message],
        author_id: Current.user.id,
        author_name: Current.user.name,
        author_email: Current.user.email,
        conversation_ai_mode: (@copilot_thread.private_conversation_id? ? ConversationAi::Consultation.mode(params[:mode]) : nil)
      }.compact,
      message_type: :user
    )
    if @copilot_thread.private_conversation_id.present?
      ConversationAi::ResponseJob.perform_later(
        copilot_thread_id: @copilot_thread.id,
        user_id: Current.user.id,
        request_message_id: @copilot_message.id,
        message: @copilot_message.message['content']
      )
    else
      @copilot_message.enqueue_response_job(params[:conversation_id], Current.user.id)
    end
  end

  private

  def set_copilot_thread
    @copilot_thread = Current.account.copilot_threads.where(user_id: Current.user.id).find(params[:copilot_thread_id])
    raise ActiveRecord::RecordNotFound if @copilot_thread.conversation_id.present?
    return if @copilot_thread.private_conversation_id.blank?

    raise ActiveRecord::RecordNotFound if @copilot_thread.private_conversation.blank?

    authorize @copilot_thread.private_conversation, :show?
  end

  def permitted_params
    params.permit(:page, :after_id, :before_id)
  end
end
