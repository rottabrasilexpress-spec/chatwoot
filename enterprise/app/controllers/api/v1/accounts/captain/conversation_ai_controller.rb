class Api::V1::Accounts::Captain::ConversationAiController < Api::V1::Accounts::BaseController
  ALLOWED_ACTIONS = %w[add_label remove_label send_public_message create_private_note set_status].freeze
  ALLOWED_STATUSES = %w[open pending resolved].freeze

  def actions
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :show?

    # Rails reserves params[:action] for the controller method name (`actions`).
    # Read the JSON body directly so the n8n contract can safely keep using
    # `action: "..."` without being overwritten by the route metadata.
    action = request.request_parameters['action'].presence || request.request_parameters[:action].presence || permitted_params[:operation].to_s
    unless ALLOWED_ACTIONS.include?(action)
      return render json: { ok: false, error: 'Ação não permitida.' }, status: :unprocessable_entity
    end

    Rails.logger.info(
      "[ConversationAi::Action] account_id=#{Current.account.id} conversation_id=#{conversation.display_id} " \
      "user_id=#{Current.user.id} action=#{action}"
    )

    before_state = conversation_state(conversation)
    result = Current.account.transaction do
      action_result = case action
                      when 'add_label'
                        update_labels(conversation, add: permitted_params[:label])
                      when 'remove_label'
                        update_labels(conversation, remove: permitted_params[:label])
                      when 'send_public_message'
                        create_message(conversation, content: permitted_params[:content], private: false)
                      when 'create_private_note'
                        create_message(conversation, content: permitted_params[:content], private: true)
                      when 'set_status'
                        update_status(conversation, permitted_params[:status])
                      end

      record_action_audit!(
        conversation: conversation,
        action: action,
        before_state: before_state,
        result: action_result
      )
      action_result
    end

    render json: { ok: true, action: action, conversation_id: conversation.display_id, result: result }
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: 'Conversa não encontrada.' }, status: :not_found
  rescue ArgumentError => e
    render json: { ok: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def update_labels(conversation, add: nil, remove: nil)
    labels = conversation.label_list
    normalized = (add || remove).to_s.strip
    raise ArgumentError, 'Etiqueta é obrigatória.' if normalized.blank?

    if add
      raise ArgumentError, 'Etiqueta não encontrada.' unless Current.account.labels.exists?(title: normalized)

      labels = (labels + [normalized]).uniq
    else
      labels = labels.reject { |label| label.casecmp?(normalized) }
    end

    conversation.update_labels(labels)
    { labels: conversation.label_list }
  end

  def create_message(conversation, content:, private:)
    raise ArgumentError, 'Texto é obrigatório.' if content.to_s.strip.blank?

    message = Messages::MessageBuilder.new(
      Current.user,
      conversation,
      ActionController::Parameters.new(content: content, private: private)
    ).perform
    { message_id: message.id, private: message.private? }
  end

  def update_status(conversation, status)
    raise ArgumentError, 'Status inválido.' unless ALLOWED_STATUSES.include?(status.to_s)

    conversation.update!(status: status)
    { status: conversation.status }
  end

  def conversation_state(conversation)
    {
      labels: conversation.label_list,
      status: conversation.status
    }
  end

  def record_action_audit!(conversation:, action:, before_state:, result:)
    Enterprise::AuditLog.create!(
      action: 'conversation_ai_action',
      auditable: conversation,
      associated: Current.account,
      user: Current.user,
      username: Current.user&.email,
      request_uuid: request.request_id,
      remote_address: request.remote_ip,
      audited_changes: {
        source: 'conversation_ai',
        action: action,
        conversation_display_id: conversation.display_id,
        before: before_state,
        after: conversation_state(conversation),
        result: result
      }.deep_stringify_keys
    )
  end

  def permitted_params
    params.permit(:conversation_id, :label, :content, :status, :operation)
  end
end
