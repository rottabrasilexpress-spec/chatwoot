json.id message.id
json.content message.content
json.inbox_id message.inbox_id
json.echo_id message.echo_id if message.echo_id
json.conversation_id message.conversation.display_id
json.message_type message.message_type_before_type_cast
json.content_type message.content_type
json.status message.status
json.content_attributes message.content_attributes
json.created_at message.created_at.to_i
json.private message.private
json.source_id message.source_id
if Current.user.is_a?(User)
  starred =
    if defined?(@starred_message_ids) && @starred_message_ids
      @starred_message_ids.include?(message.id)
    else
      MessageStar.exists?(message_id: message.id, user_id: Current.user.id)
    end
  json.starred starred
else
  json.starred false
end
json.sender message.sender.push_event_data if message.sender
json.attachments message.attachments.map(&:push_event_data) if message.attachments.present?

json.set! :call, message.call.push_event_data if message.content_type == 'voice_call' && message.respond_to?(:call) && message.call.present?
