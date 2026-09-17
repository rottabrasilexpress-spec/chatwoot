class GlobalAiActionReceipt < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :idempotency_key, presence: true, length: { maximum: 128 }
  validates :action_name, :conversation_display_id, presence: true

  def self.run!(account:, user:, idempotency_key:, action_name:, conversation_display_id:)
    receipt = create_or_find_by!(account:, user:, idempotency_key:) do |record|
      record.action_name = action_name
      record.conversation_display_id = conversation_display_id
    end

    receipt.with_lock do
      receipt.ensure_matches!(action_name:, conversation_display_id:)
      return receipt.response if receipt.completed_at?

      response = yield.deep_stringify_keys
      receipt.update!(response:, completed_at: Time.current)
      response
    end
  end

  def ensure_matches!(action_name:, conversation_display_id:)
    return if self.action_name == action_name && self.conversation_display_id.to_s == conversation_display_id.to_s

    raise ArgumentError, 'Chave idempotente já foi usada para outra ação.'
  end
end
