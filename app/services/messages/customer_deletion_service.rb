class Messages::CustomerDeletionService
  class UnsupportedMessageError < StandardError; end
  class EncryptionUnavailableError < StandardError; end

  pattr_initialize [:message!, :deleted_at]

  def perform
    raise EncryptionUnavailableError, 'Retenção segura indisponível' unless DeletedMessageContent.encryption_ready?
    raise UnsupportedMessageError, 'Somente mensagens recebidas podem ser retidas' unless retainable_message?

    message.with_lock do
      next message if message.deleted == true

      DeletedMessageContent.create!(
        message: message,
        account: message.account,
        conversation: message.conversation,
        content: message.content,
        source: 'customer',
        deleted_at: deleted_at,
        expires_at: deleted_at + DeletedMessageContent::RETENTION_PERIOD
      )

      message.update!(
        content: I18n.t('conversations.messages.deleted'),
        content_type: :text,
        content_attributes: {
          'deleted' => true,
          'deleted_by' => 'customer'
        }
      )
      message.attachments.destroy_all
    end

    message
  end

  private

  def retainable_message?
    message.incoming? && !message.private? && message.content.present?
  end
end
