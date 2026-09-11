class Api::V1::Accounts::Captain::CopilotMessagesController < Api::V1::Accounts::BaseController
  include Captain::Copilot::ConversationAccess

  before_action :set_copilot_thread

  def index
    @copilot_messages = @copilot_thread
                        .copilot_messages
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
        author_email: Current.user.email
      },
      message_type: :user
    )
    conversation_id = @copilot_thread.conversation&.display_id || params[:conversation_id]
    if @copilot_thread.conversation_id.present?
      ConversationAi::ResponseJob.perform_later(
        copilot_thread_id: @copilot_thread.id,
        user_id: Current.user.id,
        message: @copilot_message.message['content']
      )
    else
      @copilot_message.enqueue_response_job(conversation_id, Current.user.id)
    end
  end

  private

  def set_copilot_thread
    @copilot_thread = Current.account.copilot_threads.find(params[:copilot_thread_id])
    return if @copilot_thread.conversation_id.blank? && @copilot_thread.user_id == Current.user.id

    conversation = @copilot_thread.conversation
    raise ActiveRecord::RecordNotFound if conversation.blank?

    if @copilot_thread.conversation_id.present?
      authorize conversation, :show?
      return
    end

    accessible_conversation = accessible_conversation(
      account: Current.account,
      user: Current.user,
      display_id: conversation.display_id
    )
    raise ActiveRecord::RecordNotFound if accessible_conversation.blank?
  end

  def permitted_params
    params.permit(:page)
  end
end
