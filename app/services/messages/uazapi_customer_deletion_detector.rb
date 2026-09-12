class Messages::UazapiCustomerDeletionDetector
  EXPLICIT_DELETE_EVENTS = %w[
    message_delete messages_delete
    message_deleted messages_deleted
    message_revoke messages_revoke
    message_revoked messages_revoked
  ].freeze

  DELETION_KEYS = %w[
    deleted is_deleted deleted_for_everyone deletedForEveryone
    message_deleted messageDeleted revoked is_revoked
    delete_for_everyone deleteForEveryone
  ].freeze

  DELETION_VALUES = %w[
    delete deleted delete_for_everyone deleted_for_everyone
    message_deleted message_deleted_for_everyone revoke revoked
    message_revoke message_revoked
  ].freeze

  GENERIC_MESSAGE_EVENTS = %w[message messages messages_update].freeze

  def self.call(payload:, event:)
    new(payload: payload, event: event).call
  end

  def initialize(payload:, event:)
    @payload = payload
    @event = normalize(event)
  end

  def call
    return true if EXPLICIT_DELETE_EVENTS.include?(@event)
    return false unless GENERIC_MESSAGE_EVENTS.include?(@event)

    hash_nodes.any? { |node| deletion_marker?(node) }
  end

  private

  def deletion_marker?(node)
    node.any? do |key, value|
      normalized_key = normalize(key)
      next false unless normalized_deletion_keys.include?(normalized_key)

      value == true || value.to_s == '1' || normalized_deletion_values.include?(normalize(value))
    end
  end

  def normalized_deletion_keys
    @normalized_deletion_keys ||= DELETION_KEYS.map { |item| normalize(item) }
  end

  def normalized_deletion_values
    @normalized_deletion_values ||= DELETION_VALUES.map { |item| normalize(item) }
  end

  def hash_nodes(value = @payload)
    case value
    when Hash
      [value] + value.values.flat_map { |child| hash_nodes(child) }
    when Array
      value.flat_map { |child| hash_nodes(child) }
    else
      []
    end
  end

  def normalize(value)
    value.to_s.downcase.gsub(/([a-z])([A-Z])/, '\\1_\\2').gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '')
  end
end
