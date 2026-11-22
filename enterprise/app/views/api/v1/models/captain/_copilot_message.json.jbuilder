json.id resource.id
content = resource.message
if content['consultation_status'] == 'failed'
  content = content.merge('content' => ConversationAi::Consultation.failure_message)
end
json.message content
json.message_type resource.message_type
json.created_at resource.created_at.to_i
json.copilot_thread resource.copilot_thread.push_event_data
json.account_id resource.account_id
