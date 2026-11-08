# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  describe 'human unread state after a reply' do
    let(:conversation) { create(:conversation, agent_last_seen_at: 10.minutes.ago) }
    let!(:incoming) { create(:message, conversation: conversation, message_type: :incoming, created_at: 5.minutes.ago) }

    [
      { message_type: :outgoing, content_attributes: { uazapi_track_source: 'ai' } },
      { message_type: :outgoing, content_attributes: { external_echo: true } },
      { message_type: :outgoing, content_attributes: { uazapi_track_source: 'follow-up' } },
      { message_type: :outgoing },
      { message_type: :outgoing, private: true },
      { message_type: :template }
    ].each do |attributes|
      it "preserves unread customer messages for #{attributes}" do
        reply = build(:message, conversation: conversation, **attributes)
        # Exercise the commit callback without dispatching/sending a real reply.
        %i[reopen_conversation enforce_rotta_archived_conversation_status mark_rotta_archived_conversation_pending
           mark_pending_conversation_as_open_for_human_response set_conversation_activity dispatch_create_events
           send_reply execute_message_template_hooks update_contact_activity].each do |callback|
          allow(reply).to receive(callback)
        end
        last_seen_at = conversation.reload.agent_last_seen_at

        reply.send(:execute_after_create_commit_callbacks)

        expect(conversation.reload.agent_last_seen_at).to eq(last_seen_at)
        expect(conversation.unread_incoming_messages.map(&:id)).to include(incoming.id)
      end
    end
  end
end
