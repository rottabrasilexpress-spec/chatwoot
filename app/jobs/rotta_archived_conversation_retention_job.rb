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
    archived = archived_label_scope
               .where("additional_attributes->>'rotta_archived_at' <= ?", cutoff.iso8601)

    # Existing conversations without the Rotta timestamp (created before this
    # rule) are covered by their last interaction. The business rule is based
    # on inactivity, regardless of whether the old conversation is still open.
    stale_conversations = Conversation.where('last_activity_at < ?', cutoff)

    archived.or(stale_conversations).distinct
  end

  def archived_label_scope
    Conversation.where(
      'cached_label_list = :label OR cached_label_list LIKE :prefix OR cached_label_list LIKE :suffix OR cached_label_list LIKE :middle',
      label: 'arquivado',
      prefix: 'arquivado,%',
      suffix: '%,arquivado',
      middle: '%,arquivado,%'
    )
  end
end

RottaArchivedConversationRetentionJob.prepend_mod_with('RottaArchivedConversationRetentionJob')
