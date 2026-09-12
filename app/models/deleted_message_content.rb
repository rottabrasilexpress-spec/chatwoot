class DeletedMessageContent < ApplicationRecord
  RETENTION_PERIOD = 48.hours

  belongs_to :message
  belongs_to :account
  belongs_to :conversation

  encrypts :content if Chatwoot.encryption_configured?

  validates :content, presence: true
  validates :source, inclusion: { in: ['customer'] }
  validates :deleted_at, :expires_at, presence: true
  validates :message_id, uniqueness: true

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def self.encryption_ready?
    Chatwoot.encryption_configured?
  end

  def active?
    expires_at.present? && expires_at > Time.current
  end
end
