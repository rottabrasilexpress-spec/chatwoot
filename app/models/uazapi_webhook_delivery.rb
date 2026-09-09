class UazapiWebhookDelivery < ApplicationRecord
  STATUSES = %w[received processing persisted duplicate ignored failed].freeze
  TERMINAL_STATUSES = %w[persisted duplicate ignored failed].freeze

  belongs_to :account
  belongs_to :conversation, optional: true

  validates :account_id, :event, :status, :attempts, :received_at, :payload_digest, :correlation_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  scope :recent, -> { where(received_at: 24.hours.ago..) }
  scope :failed_deliveries, -> { where(status: 'failed') }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end
end
