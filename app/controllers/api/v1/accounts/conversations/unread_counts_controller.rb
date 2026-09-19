class Api::V1::Accounts::Conversations::UnreadCountsController < Api::V1::Accounts::BaseController
  before_action :ensure_unread_counts_enabled

  def index
    counts = if filtered_unread_counts_enabled?
               instrumentation.summarize_request(account_id: Current.account.id) { unread_counts }
             else
               unread_counts
             end
    render json: { payload: counts }
  end

  private

  def unread_counts
    counts = ::Conversations::UnreadCounts::Counter.new(account: Current.account, user: Current.user).perform
    return counts unless rotta_account?

    counts.merge(all_count: 0, inboxes: {}, labels: {}, teams: {})
  end

  def filtered_unread_counts_enabled?
    Current.account.feature_enabled?(::Conversations::UnreadCounts::FilteredCounter::FEATURE_FLAG)
  end

  def instrumentation
    ::Conversations::UnreadCounts::FilteredCountInstrumentation
  end

  def ensure_unread_counts_enabled
    return if Current.account.feature_enabled?('conversation_unread_counts')
    return if rotta_account?

    render json: { error: I18n.t('errors.conversations.unread_counts.feature_not_enabled') }, status: :forbidden
  end

  def rotta_account?
    Current.account.id.to_i == ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  end
end
