class RottaUazapiWebhookDeliveryRetentionJob < ApplicationJob
  queue_as :housekeeping

  RETENTION_PERIOD = ENV.fetch('ROTTABRASIL_UAZAPI_DELIVERY_RETENTION_DAYS', '30').to_i.clamp(7, 90).days
  BATCH_SIZE = 1_000

  def perform
    UazapiWebhookDelivery.where('received_at < ?', RETENTION_PERIOD.ago).in_batches(of: BATCH_SIZE, &:delete_all)
  end
end
