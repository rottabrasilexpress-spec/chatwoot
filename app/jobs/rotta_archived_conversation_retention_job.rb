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
    archived_conversations = archived_label_scope(resolved_rotta_conversations)
    archived = archived_conversations
               .where("additional_attributes->>'rotta_archived_at' <= ?", cutoff.iso8601)

    # Existing conversations without the Rotta timestamp (created before this
    # rule) are covered by their last interaction. Restrict this fallback to
    # resolved Rotta conversations that predate the timestamp rule, so a newly
    # archived conversation cannot be deleted just because its old activity is
    # outside the retention window.
    stale_conversations = archived_conversations.where(
      "additional_attributes->>'rotta_archived_at' IS NULL"
    ).where('last_activity_at < ?', cutoff)

    archived.or(stale_conversations).distinct
  end

  def archived_label_scope(scope)
    scope.where(
      'cached_label_list ~* :pattern',
      pattern: '(^|,)(\\[[0-9]+\\] |[0-9]+-)?arquivados?(,|$)'
    )
  end

  def rotta_account_id
    ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  end
end

RottaArchivedConversationRetentionJob.prepend_mod_with('RottaArchivedConversationRetentionJob')
