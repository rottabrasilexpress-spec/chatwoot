class Api::V1::Accounts::GlobalAi::ActionsController < Api::V1::Accounts::BaseController
  def create
    GlobalAiAssistant::AccessPolicy.ensure_allowed!(account: Current.account, user: Current.user)
    result = GlobalAiAssistant::ActionService.new(
      account: Current.account,
      user: Current.user,
      action: request.request_parameters['action'].presence || params[:operation],
      conversation_id: params[:conversation_id],
      confirmed: params[:confirmed],
      params: params,
      idempotency_key: params[:idempotency_key]
    ).call
    render json: result, status: result[:confirmation_required] ? :accepted : :ok
  rescue GlobalAiAssistant::AccessPolicy::AccessDenied => e
    render json: { error: e.message }, status: :forbidden
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversa, agente ou etiqueta não encontrada.' }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue RottaFollowUp::AdminClient::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end
end
