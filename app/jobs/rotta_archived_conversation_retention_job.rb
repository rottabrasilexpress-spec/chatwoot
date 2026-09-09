class RottaArchivedConversationRetentionJob < ApplicationJob
  queue_as :housekeeping

  RETENTION_PERIOD = 1.month + 20.days
  BATCH_SIZE = 100

  def perform
    cutoff = Time.current - RETENTION_PERIOD
    candidates(cutoff).find_each(batch_size: BATCH_SIZE) do |conversation|
      Rails.logger.info(
        "[Rotta retention] deleting conversation=#{conversation.id} " \
        "account=#{conversation.account_id} last_activity_at=#{conversation.last_activity_at}"
      )
      conversation.destroy!
    rescue StandardError => e
      Rails.logger.error(
        "[Rotta retention] failed conversation=#{conversation.id}: #{e.class}: #{e.message}"
      )
    end
  end

  private

  def candidates(cutoff)
    resolved_rotta_conversations = Conversation.where(
      account_id: rotta_account_id,
      status: :resolved
    )
    archived = archived_label_scope(resolved_rotta_conversations)
               .where("additional_attributes->>'rotta_archived_at' <= ?", cutoff.iso8601)

    # Existing conversations without the Rotta timestamp (created before this
    # rule) are covered by their last interaction. Restrict this fallback to
    # resolved Rotta conversations so this housekeeping job cannot remove
    # another account's data or an active conversation.
    stale_conversations = resolved_rotta_conversations.where('last_activity_at < ?', cutoff)

    archived.or(stale_conversations).distinct
  end

  def archived_label_scope(scope)
    scope.where(
      'cached_label_list = :label OR cached_label_list LIKE :prefix OR cached_label_list LIKE :suffix OR cached_label_list LIKE :middle',
      label: 'arquivado',
      prefix: 'arquivado,%',
      suffix: '%,arquivado',
      middle: '%,arquivado,%'
    )
  end

  def rotta_account_id
    ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  end
end

RottaArchivedConversationRetentionJob.prepend_mod_with('RottaArchivedConversationRetentionJob')
