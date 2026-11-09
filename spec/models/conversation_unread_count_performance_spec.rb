require 'rails_helper'

RSpec.describe Conversation do
  it 'counts pending incoming messages without loading their text or media' do
    conversation = create(:conversation, agent_last_seen_at: 1.hour.ago)
    create_list(:message, 12, conversation: conversation, message_type: :incoming, created_at: 1.minute.ago)
    create(:message, conversation: conversation, message_type: :outgoing, created_at: Time.current)
    create(:message, conversation: conversation, message_type: :incoming, created_at: 2.hours.ago)
    expected = conversation.unread_incoming_messages.count
    instantiated_messages = 0
    listener = lambda do |*args|
      payload = ActiveSupport::Notifications::Event.new(*args).payload
      instantiated_messages += payload[:record_count] if payload[:class_name] == 'Message'
    end

    actual = ActiveSupport::Notifications.subscribed(listener, 'instantiation.active_record') do
      conversation.unread_incoming_message_count
    end
    expect(actual).to eq(expected)
    expect(actual).to eq(10)
    expect(instantiated_messages).to eq(0)

    conversation.update!(agent_last_seen_at: Time.current)
    expect(conversation.unread_incoming_message_count).to eq(0)
  end
end
