# frozen_string_literal: true

require 'digest'

module Rotta
  class CaioAttentionAlert
    TARGET_LABEL_KEY = 'caioatencao'
    TARGET_LABEL = 'caio-atencao'
    ACCOUNT_ENV = 'ROTTABRASIL_CHATWOOT_ACCOUNT_ID'
    USER_ENV = 'ROTTABRASIL_CAIO_USER_ID'

    class << self
      def call(conversation:, changed_attributes:, occurred_at:)
        return unless rotta_account?(conversation)

        previous_labels, current_labels = label_transition(changed_attributes)
        return unless previous_labels && current_labels
        return if normalized_labels(previous_labels).include?(TARGET_LABEL_KEY)
        return unless normalized_labels(current_labels).include?(TARGET_LABEL_KEY)

        caio = configured_caio(conversation.account)
        return if caio.blank? || caio.pubsub_token.blank?

        {
          kind: 'label-added',
          recipient_pubsub_token: caio.pubsub_token,
          recipient_user_id: caio.id,
          alert_id: alert_id(conversation, occurred_at, previous_labels, current_labels),
          conversation_id: conversation.display_id,
          inbox_id: conversation.inbox_id,
          label: TARGET_LABEL,
          occurred_at: occurred_at.to_f,
          title: 'Caio Atenção',
          message: 'A etiqueta Caio Atenção foi adicionada a esta conversa.',
          contact: contact_data(conversation)
        }
      end

      private

      def rotta_account?(conversation)
        conversation.account_id.to_i == ENV.fetch(ACCOUNT_ENV, '1').to_i
      end

      def configured_caio(account)
        raw_user_id = ENV[USER_ENV].presence || ENV['ROTTABRASIL_ATTENTION_TARGET_USER_ID'].presence
        user_id = Integer(raw_user_id, 10) if raw_user_id
        return warn_missing_configuration(account) if user_id.blank?

        account.users.find_by(id: user_id).tap do |user|
          Rails.logger.warn("[RottaCaioAttention] configured user #{user_id} is not a valid account user") if user.blank?
        end
      rescue ArgumentError
        warn_missing_configuration(account)
      end

      def warn_missing_configuration(account)
        Rails.logger.warn("[RottaCaioAttention] skipped for account #{account.id}: #{USER_ENV} is missing or invalid")
        nil
      end

      def label_transition(changed_attributes)
        return unless changed_attributes.is_a?(Hash)

        change = changed_attributes['label_list'] || changed_attributes[:label_list] ||
                 changed_attributes['cached_label_list'] || changed_attributes[:cached_label_list] ||
                 changed_attributes['labels'] || changed_attributes[:labels]
        return unless change.is_a?(Array) && change.length == 2

        change
      end

      def normalized_labels(labels)
        Array(labels).map do |label|
          label.to_s.unicode_normalize(:nfkd).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
            .downcase.gsub(/[^a-z0-9]/, '')
        end
      end

      def alert_id(conversation, occurred_at, previous_labels, current_labels)
        source = [
          'caio-attention-v1', conversation.id, occurred_at.utc.iso8601(6),
          Array(previous_labels).sort.join(','), Array(current_labels).sort.join(',')
        ].join("\0")
        Digest::SHA256.hexdigest(source)
      end

      def contact_data(conversation)
        contact = conversation.contact
        return {} if contact.blank?

        {
          id: contact.id,
          name: contact.name,
          phone_number: contact.phone_number,
          avatar_url: contact.avatar_url
        }.compact
      end
    end
  end
end
