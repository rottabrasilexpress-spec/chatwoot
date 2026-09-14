class Api::V1::Accounts::GlobalAi::ThreadsController < Api::V1::Accounts::BaseController
  before_action :ensure_global_access!

  def index
    threads = Current.account.global_ai_threads.where(user_id: Current.user.id).order(updated_at: :desc).limit(20)
    render json: threads.map { |thread| thread_payload(thread) }
  end

  def create
    question = params[:message].to_s.strip
    return render json: { error: 'Pergunta obrigatória.' }, status: :unprocessable_entity if question.blank?

    thread = Current.account.global_ai_threads.create!(user: Current.user, title: question.truncate(120))
    render json: ask_and_persist(thread, question), status: :created
  rescue StandardError => e
    Rails.logger.error("[GlobalAi] #{e.class}: #{e.message}")
    render json: { error: 'Não foi possível responder agora.', detail: e.message }, status: :bad_gateway
  end

  def show
    render json: thread_payload(thread)
  end

  private

  def thread
    @thread ||= Current.account.global_ai_threads.find(params[:id]).tap do |record|
      raise ActiveRecord::RecordNotFound unless record.user_id == Current.user.id
    end
  end

  def ask_and_persist(thread, question)
    thread.global_ai_messages.create!(message_type: :user, message: { content: question })
    response = GlobalAiAssistant::AskService.new(
      account: Current.account,
      user: Current.user,
      thread: thread,
      question: question
    ).call
    thread.global_ai_messages.create!(message_type: :assistant, message: response)
    { thread: thread_payload(thread), response: response }
  end

  def thread_payload(thread)
    {
      id: thread.id,
      title: thread.title,
      created_at: thread.created_at.to_i,
      updated_at: thread.updated_at.to_i,
      messages: thread.global_ai_messages.order(created_at: :asc).map do |message|
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
