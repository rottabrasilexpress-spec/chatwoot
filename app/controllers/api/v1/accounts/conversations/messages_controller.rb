class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: [:update, :edit, :react, :pin, :forward]
  before_action :ensure_user_can_star, only: :star

  def index
    @messages = message_finder.perform
    if Current.user.is_a?(User)
      message_ids = @messages.map(&:id)
      @starred_message_ids = MessageStar.where(user_id: Current.user.id, message_id: message_ids).pluck(:message_id)
    end
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def deleted_content
    retained_content = message.deleted_message_content
    return head :not_found unless retained_content&.active?

    authorize retained_content, :show?
    @deleted_message_content = retained_content
  end

  def edit
    text = permitted_params[:text].to_s
    validate_editable_message!(text)

    Messages::UazapiActionService.new(message: message, action: :edit, text: text).perform
    message.update!(
      content: text,
      content_attributes: message_content_attributes.merge(
        'edited' => true,
        'uazapi_edited_at' => Time.current.iso8601
      )
    )
    @message = message
  rescue Messages::UazapiActionService::ProviderError, ArgumentError => e
    render_action_error(e)
  end

  def react
    emoji = permitted_params[:emoji].to_s
    validate_reaction!(emoji)

    Messages::UazapiActionService.new(message: message, action: :react, emoji: emoji).perform
    attributes = message_content_attributes
    emoji.present? ? attributes['rotta_reaction'] = emoji : attributes.delete('rotta_reaction')
    message.update!(content_attributes: attributes)
    @message = message
  rescue Messages::UazapiActionService::ProviderError, ArgumentError => e
    render_action_error(e)
  end

  def pin
    pin = permitted_params[:pin].nil? || ActiveModel::Type::Boolean.new.cast(permitted_params[:pin])
    duration = permitted_params[:duration].to_i

    Messages::UazapiActionService.new(message: message, action: :pin, pin: pin, duration: duration).perform
    attributes = message_content_attributes
    if pin
      attributes['rotta_pinned'] = true
      attributes['rotta_pinned_duration'] = [1, 7, 30].include?(duration) ? duration : 30
    else
      attributes.delete('rotta_pinned')
      attributes.delete('rotta_pinned_duration')
    end
    message.update!(content_attributes: attributes)
    @message = message
  rescue Messages::UazapiActionService::ProviderError, ArgumentError => e
    render_action_error(e)
  end

  def forward
    target_conversation = Current.account.conversations.find_by!(display_id: permitted_params[:target_conversation_id])
    authorize target_conversation, :show?
    raise ActiveRecord::RecordNotFound unless target_conversation.inbox.api?
    raise ArgumentError, 'Somente mensagens de texto podem ser encaminhadas.' if message.content.blank? || message.attachments.present?

    @message = Messages::MessageBuilder.new(
      Current.user,
      target_conversation,
      ActionController::Parameters.new(
        content: message.content,
        private: false,
        content_attributes: {
          rotta_forwarded: true,
          forwarded_from_message_id: message.id,
          forwarded_from_conversation_id: @conversation.display_id
        }
      )
    ).perform
  rescue ArgumentError => e
    render_action_error(e)
  end

  def star
    starred = permitted_params[:starred].nil? || ActiveModel::Type::Boolean.new.cast(permitted_params[:starred])
    star = MessageStar.find_or_initialize_by(message: message, user: Current.user)

    if starred
      star.account = Current.account
      star.save!
    else
      star.destroy! if star.persisted?
    end

    @message = message
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => e
    render_action_error(e)
  end

  def destroy
    provider_id_present = message.source_id.present? || message.additional_attributes&.[]('uazapi_message_id').present?
    if @conversation.inbox.api? && provider_id_present && Messages::UazapiActionService.configured?
      Messages::UazapiActionService.new(message: message, action: :delete).perform
    end

    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  rescue Messages::UazapiActionService::ProviderError, ArgumentError => e
    render_action_error(e)
  end

  def retry
    return if message.blank?

    ::SendReplyJob.perform_later(message.id) if claim_message_retry
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def claim_message_retry
    message.with_lock do
      next false unless message.failed?

      Messages::StatusUpdateService.new(message, 'sent').perform
      previous_source_id = message.source_id
      retry_attributes = { content_attributes: {} }
      retry_attributes[:source_id] = nil unless @conversation.inbox.api? || @conversation.inbox.web_widget?
      message.update!(retry_attributes)
      if retry_attributes.key?(:source_id) && previous_source_id.present?
        Rails.logger.info "Cleared older source ID #{previous_source_id} for message #{message.id}"
      end
      true
    end
  end

  def permitted_params
    params.permit(
      :id,
      :target_language,
      :status,
      :external_error,
      :text,
      :emoji,
      :pin,
      :duration,
      :target_conversation_id,
      :starred
    )
  end

  def message_content_attributes
    message.content_attributes.is_a?(Hash) ? message.content_attributes.deep_dup.stringify_keys : {}
  end

  def validate_editable_message!(text)
    raise ArgumentError, 'Mensagem de texto vazia.' if text.blank?
    raise ArgumentError, 'Mensagem não pode ser editada.' unless message.outgoing? && !message.private? && message.text?
    raise ArgumentError, 'Mensagem já excluída.' if message.deleted == true
    raise ArgumentError, 'Mensagem excede o limite permitido.' if text.length > 150_000
  end

  def validate_reaction!(emoji)
    raise ArgumentError, 'Mensagem já excluída.' if message.deleted == true
    raise ArgumentError, 'Reação inválida.' if emoji.length > 16
  end

  def ensure_user_can_star
    return if Current.user.is_a?(User)

    render json: { error: 'Somente agentes podem favoritar mensagens.' }, status: :forbidden
  end

  def render_action_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
