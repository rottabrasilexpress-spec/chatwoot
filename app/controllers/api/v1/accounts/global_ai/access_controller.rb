class Api::V1::Accounts::GlobalAi::AccessController < Api::V1::Accounts::BaseController
  def show
    access = GlobalAiAssistant::AccessPolicy.access_for(account: Current.account, user: Current.user)
    render json: access.merge(
      agents: GlobalAiAssistant::AccessPolicy.shareable_agents(Current.account).map { |agent| agent.attributes.slice('id', 'name', 'email') }
    )
  rescue GlobalAiAssistant::AccessPolicy::AccessDenied => e
    render json: { error: e.message }, status: :forbidden
  end

  def update
    access = GlobalAiAssistant::AccessPolicy.update_shared_users!(
      account: Current.account,
      user: Current.user,
      user_ids: params[:user_ids]
    )
    render json: access.merge(shared_user_ids: access[:shared_user_ids])
  rescue GlobalAiAssistant::AccessPolicy::AccessDenied => e
    render json: { error: e.message }, status: :forbidden
  end
end
