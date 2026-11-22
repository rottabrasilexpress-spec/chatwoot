class RottaAutomaticLabelListener < BaseListener
  def conversation_updated(event)
    conversation = event.data[:conversation]
    return unless defined?(ConversationAiBrief) && conversation && ConversationAiBrief.enabled_for?(conversation.account_id)
    return unless ConversationAiBrief.recipient_id

    changes = event.data[:changed_attributes]
    return unless changes

    previous, current = changes['label_list'] || changes[:label_list]
    return unless previous.is_a?(Array) && current.is_a?(Array)

    previous_targets = ConversationAiBrief.target_labels(previous)
    current_targets = ConversationAiBrief.target_labels(current)
    return if previous_targets == current_targets

    delay = (current_targets - previous_targets).empty? ? 0 : 8.seconds
    ConversationAi::AutomaticBriefJob.set(wait: delay).perform_later(
      conversation.id, event.timestamp.utc.iso8601(6), previous.map { |label| label.to_s.parameterize }, current_targets
    )
  rescue StandardError => e
    Rails.logger.warn("[ConversationAi::AutomaticBrief] label event error=#{e.class}")
  end

  def message_created(event)
    message = event.data[:message]
    return unless message&.account_id

    Rotta::AutomaticLabelsJob.perform_later(message.id)
  end
end
