module Conversations
  class RequestAttentionService
    REQUESTER_ID_ENV = 'ROTTABRASIL_ATTENTION_REQUESTER_USER_ID'
    TARGET_ID_ENV = 'ROTTABRASIL_ATTENTION_TARGET_USER_ID'

    pattr_initialize [:conversation!, :requester!]

    def perform
      target = configured_target
      raise ActiveRecord::RecordNotFound, 'Attention target is not configured' if target.blank?

      alert_id = "attention-request:#{conversation.id}:#{Time.current.to_i}:#{requester.id}"
      payload = {
        account_id: conversation.account_id,
        alert_id: alert_id,
        conversation_id: conversation.display_id,
        inbox_id: conversation.inbox_id,
        occurred_at: Time.current.to_i,
        contact: {
          id: conversation.contact_id,
          name: conversation.contact.name,
          phone_number: conversation.contact.phone_number,
          avatar_url: conversation.contact.avatar_url
        },
        title: 'Solicitação de atenção',
        message: 'Este cliente é um possível fechamento e precisa de atenção.'
      }

      ActionCableBroadcastJob.perform_later(
        [target.pubsub_token],
        Events::Types::CONVERSATION_ATTENTION_REQUESTED,
        payload
      )

      payload
    end

    private

    attr_reader :conversation, :requester

    def configured_target
      target_id = ENV[TARGET_ID_ENV].to_i
      return if target_id.zero?

      User.joins(:accounts).where(accounts: { id: conversation.account_id }, id: target_id).first
    end
  end
end
