class ConversationAi::AutomaticBriefJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, timestamp, previous_labels, next_labels)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation && ConversationAiBrief.enabled_for?(conversation.account_id)

    membership = conversation.account.account_users.find_by(user_id: ConversationAiBrief.recipient_id)
    return unless membership && can_read?(membership, conversation)

    new_assignment = (next_labels - ConversationAiBrief.target_labels(previous_labels)).any?
    brief = reserve(conversation, membership.user, Time.iso8601(timestamp), next_labels, new_assignment)
    return unless brief && brief.state == 'processing'

    generate(brief, membership, previous_labels)
  end

  private

  def can_read?(membership, conversation)
    ConversationPolicy.new({ account: conversation.account, account_user: membership, user: membership.user }, conversation).show?
  end

  def reserve(conversation, recipient, timestamp, labels, new_assignment)
    conversation.with_lock do
      next unless labels == ConversationAiBrief.target_labels(conversation.label_list)

      brief = ConversationAiBrief.find_or_initialize_by(conversation: conversation, user: recipient)
      next if !new_assignment && brief.new_record?
      next if brief.persisted? && brief.triggered_at >= timestamp

      brief.update!(
        labels: labels, triggered_at: timestamp, state: new_assignment ? 'processing' : 'cancelled',
        customer_message_id: ConversationAiBrief.latest_customer_message_id(conversation), result: {}
      )
      brief
    end
  end

  def generate(brief, membership, previous_labels)
    event_time = brief.triggered_at
    result = ConversationAi::AutomaticBrief.new(brief: brief, previous_labels: previous_labels).call
    finish(brief, membership, event_time, result ? 'ready' : 'skipped', result || {})
  rescue StandardError => e
    Rails.logger.warn("[ConversationAi::AutomaticBrief] conversation_id=#{brief.conversation_id} error=#{e.class}")
    finish(brief, membership, event_time, 'failed', {})
  end

  def finish(brief, membership, event_time, state, result)
    changed = brief.conversation.with_lock do
      brief.reload
      next unless brief.triggered_at == event_time && brief.state == 'processing'

      fresh_labels = ConversationAiBrief.target_labels(brief.conversation.label_list)
      latest_message = ConversationAiBrief.latest_customer_message_id(brief.conversation)
      if brief.labels != fresh_labels || brief.customer_message_id != latest_message
        brief.update!(state: 'cancelled', result: {})
        next
      end

      brief.update!(state: state, result: result)
    end
    return unless changed && state.in?(%w[ready failed]) && can_read?(membership, brief.conversation)

    ActionCableBroadcastJob.perform_later(
      [membership.user.pubsub_token], 'conversation.ai_brief_updated',
      { account_id: brief.conversation.account_id, conversation_id: brief.conversation.display_id }
    )
  end
end
