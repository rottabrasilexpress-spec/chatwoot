class ConversationAiBrief < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  ENABLE_ENV = 'ROTTA_CONVERSATION_AI_AUTOMATIC_BRIEF'.freeze
  LABELS = %w[caio-atencao kelvin].freeze

  def self.enabled_for?(account_id)
    ENV[ENABLE_ENV] == 'true' && account_id.to_s == ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1')
  end

  def self.recipient_id
    id = ENV['ROTTABRASIL_ATTENTION_REQUESTER_USER_ID'].to_i
    id if id.positive? && id != ENV['ROTTABRASIL_CAIO_USER_ID'].to_i
  end

  def self.target_labels(labels)
    normalized = Array(labels).map { |label| label.to_s.parameterize }
    LABELS & normalized
  end

  def self.latest_customer_message_id(conversation)
    conversation.messages.incoming.where(private: false, sender_type: 'Contact').maximum(:id)
  end

  def available?
    state.in?(%w[ready failed]) && labels == self.class.target_labels(conversation.label_list) &&
      customer_message_id == self.class.latest_customer_message_id(conversation)
  end
end
