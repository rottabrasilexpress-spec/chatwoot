module Conversations
  class RequestAttentionService
    REQUESTER_ID_ENV = 'ROTTABRASIL_ATTENTION_REQUESTER_USER_ID'
    TARGET_ID_ENVS = %w[
      ROTTABRASIL_CAIO_USER_ID
      ROTTABRASIL_ATTENTION_TARGET_USER_ID
    ].freeze

    pattr_initialize [:conversation!, :requester!]

    def perform
      target = configured_target
      raise ActiveRecord::RecordNotFound, 'Attention target is not configured' if target.blank?

      alert_id = "attention-request:#{conversation.id}:#{Time.current.to_i}:#{requester.id}"
      contact = conversation.contact
      payload = {
        account_id: conversation.account_id,
        kind: 'attention-requested',
        recipient_user_id: target.id,
        alert_id: alert_id,
        conversation_id: conversation.display_id,
        inbox_id: conversation.inbox_id,
        label: 'solicitar-atencao',
        occurred_at: Time.current.to_i,
        contact: {
          id: conversation.contact_id,
          name: contact&.name,
          phone_number: contact&.phone_number,
          avatar_url: contact&.avatar_url
        }.compact,
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
      target_id = configured_target_id
      return if target_id.zero?

      conversation.account.users.find_by(id: target_id)
    end

    def configured_target_id
      raw_id = TARGET_ID_ENVS.filter_map { |key| ENV[key].presence }.first
      Integer(raw_id, 10)
    rescue ArgumentError, TypeError
      0
    end
  end
end
