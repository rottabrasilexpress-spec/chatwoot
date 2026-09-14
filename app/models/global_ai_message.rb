# == Schema Information
#
# Table name: global_ai_messages
#
#  id                :bigint           not null, primary key
#  account_id        :bigint           not null
#  global_ai_thread_id :bigint         not null
#  message_type      :integer          default("user"), not null
#  message           :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class GlobalAiMessage < ApplicationRecord
  belongs_to :global_ai_thread
  belongs_to :account

  enum message_type: { user: 0, assistant: 1 }

  validates :message_type, presence: true
  validates :message, presence: true
  before_validation :ensure_account
  validate :validate_message_attributes

  private

  def ensure_account
    self.account_id = global_ai_thread&.account_id
  end

  def validate_message_attributes
    return if message.blank?

    allowed_keys = %w[
      content answer cards actions sources model error request_id context_summary
    ]
    invalid_keys = message.keys.map(&:to_s) - allowed_keys
    errors.add(:message, "contains invalid attributes: #{invalid_keys.join(', ')}") if invalid_keys.any?
  end
end
