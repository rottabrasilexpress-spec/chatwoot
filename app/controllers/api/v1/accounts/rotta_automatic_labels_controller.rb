class Api::V1::Accounts::RottaAutomaticLabelsController < Api::V1::Accounts::BaseController
  before_action :ensure_agent

  def show
    render json: payload
  end

  def update
    Rotta::AutomaticLabels::Settings.update(Current.account, params.require(:settings).permit(*Rotta::AutomaticLabels::Settings::KEYS))
    render json: payload
  end

  private

  def ensure_agent
    return if Current.account_user&.agent? || Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end

  def payload
    logs = Current.account.rotta_automatic_label_logs.order(created_at: :desc).limit(40)
    {
      settings: Rotta::AutomaticLabels::Settings.for(Current.account),
      logs: logs.map do |log|
        {
          id: log.id, automation_key: log.automation_key, status: log.status,
          error_message: log.error_message, conversation_id: log.conversation_id,
          metadata: log.metadata, created_at: log.created_at
        }
      end
    }
  end
end
