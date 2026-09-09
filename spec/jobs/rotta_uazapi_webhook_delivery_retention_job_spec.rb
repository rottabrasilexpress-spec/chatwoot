require 'rails_helper'

RSpec.describe RottaUazapiWebhookDeliveryRetentionJob, type: :job do
  let(:account) { create(:account) }
  let(:delivery_attributes) do
    {
      account: account,
      event: 'contacts',
      status: 'ignored',
      attempts: 1,
      received_at: Time.current,
      payload_digest: SecureRandom.hex(32),
      correlation_id: SecureRandom.uuid,
      metadata: {}
    }
  end

  it 'uses the housekeeping queue' do
    expect(described_class.queue_name).to eq('housekeeping')
  end

  it 'deletes only deliveries older than the configured retention period' do
    recent_delivery = UazapiWebhookDelivery.create!(delivery_attributes)
    old_delivery = UazapiWebhookDelivery.create!(delivery_attributes.merge(
                                                    received_at: 31.days.ago,
                                                    payload_digest: SecureRandom.hex(32),
                                                    correlation_id: SecureRandom.uuid
                                                  ))

    described_class.perform_now

    expect(UazapiWebhookDelivery.where(id: recent_delivery.id)).to exist
    expect(UazapiWebhookDelivery.where(id: old_delivery.id)).not_to exist
  end
end
