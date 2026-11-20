json.payload @labels
if @pickup
  json.contact @conversation.contact.push_event_data
  json.rotta_pickup @pickup.conversation_dates
end
