class RottaDeletedMessageContentRetentionJob < ApplicationJob
  queue_as :housekeeping

  BATCH_SIZE = 100

  def perform
    DeletedMessageContent.expired.in_batches(of: BATCH_SIZE, &:delete_all)
  end
end
