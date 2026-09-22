class RottaAutomaticLabelLog < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :message, optional: true

  validates :automation_key, :status, :event_key, presence: true
  validates :event_key, uniqueness: { scope: :account_id }
end
