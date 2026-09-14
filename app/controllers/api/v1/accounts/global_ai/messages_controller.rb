class Api::V1::Accounts::GlobalAi::MessagesController < Api::V1::Accounts::BaseController
  before_action :ensure_global_access!

  def index
    render json: thread_payload
  end

  def create
    question = params[:message].to_s.strip
    return render json: { error: 'Pergunta obrigatória.' }, status: :unprocessable_entity if question.blank?

    thread = current_thread
    thread.global_ai_messages.create!(message_type: :user, message: { content: question })
    response = GlobalAiAssistant::AskService.new(
      account: Current.account,
      user: Current.user,
      thread: thread,
      question: question
    ).call
    thread.global_ai_messages.create!(message_type: :assistant, message: response)
    render json: { thread: thread_payload, response: response }, status: :created
  rescue StandardError => e
    Rails.logger.error("[GlobalAi] #{e.class}: #{e.message}")
    render json: { error: 'Não foi possível responder agora.', detail: e.message }, status: :bad_gateway
  end

  private

  def current_thread
    @current_thread ||= Current.account.global_ai_threads.find(params[:thread_id]).tap do |thread|
      raise ActiveRecord::RecordNotFound unless thread.user_id == Current.user.id
    end
  end

  def thread_payload
    {
      id: current_thread.id,
      title: current_thread.title,
      created_at: current_thread.created_at.to_i,
      updated_at: current_thread.updated_at.to_i,
      messages: current_thread.global_ai_messages.order(created_at: :asc).map do |message|
        { id: message.id, message: message.message, message_type: message.message_type, created_at: message.created_at.to_i }
      end
    }
  end

  def ensure_global_access!
    GlobalAiAssistant::AccessPolicy.ensure_allowed!(account: Current.account, user: Current.user)
  rescue GlobalAiAssistant::AccessPolicy::AccessDenied => e
    render json: { error: e.message }, status: :forbidden
  end
end
