class GlobalAiAssistant::ActionService
  ALLOWED_ACTIONS = %w[
    add_label remove_label set_status create_private_note send_public_message assign_agent
    follow_up_dispatch_now follow_up_advance follow_up_delay follow_up_cancel
  ].freeze
  ALLOWED_STATUSES = %w[open pending resolved].freeze

  def initialize(account:, user:, action:, conversation_id:, confirmed:, params: {})
    @account = account
    @user = user
    @action = action.to_s
    @conversation_id = conversation_id
    @confirmed = ActiveModel::Type::Boolean.new.cast(confirmed)
    @params = params.to_h.stringify_keys
  end

  def call
    raise ArgumentError, 'Ação não permitida.' unless ALLOWED_ACTIONS.include?(@action)

    conversation = @account.conversations.find_by!(display_id: @conversation_id)
    Pundit.authorize(@user, conversation, :show?)
    return confirmation_payload(conversation) unless @confirmed

    before_state = { labels: conversation.label_list, status: conversation.status, assignee_id: conversation.assignee_id }
    result = @account.transaction do
      result = execute!(conversation)
      record_audit!(conversation, before_state, result)
      result
    end

    { ok: true, action: @action, conversation_id: conversation.display_id, result: result }
  end

  private

  def confirmation_payload(conversation)
    {
      ok: false,
      confirmation_required: true,
      action: @action,
      conversation_id: conversation.display_id,
      customer_name: conversation.contact&.name,
      summary: confirmation_summary(conversation)
    }
  end

  def confirmation_summary(conversation)
    case @action
    when 'send_public_message'
      "Enviar mensagem pública para #{conversation.contact&.name || 'o cliente'}: #{@params['content']}"
    when 'create_private_note'
      "Criar uma nota privada em #{conversation.contact&.name || 'a conversa'}: #{@params['content']}"
    when 'set_status'
      "Alterar o status da conversa para #{@params['status']}"
    when /\Afollow_up_/
      operation = @action.delete_prefix('follow_up_')
      hours = @params['hours'].presence
      detail = hours ? " para #{hours} horas" : ''
      "Executar o follow-up #{operation}#{detail} na conversa #{conversation.display_id}"
    else
      "Executar #{@action} na conversa #{conversation.display_id}"
    end
  end

  def execute!(conversation)
    case @action
    when 'add_label' then update_labels(conversation, add: @params['label'])
    when 'remove_label' then update_labels(conversation, remove: @params['label'])
    when 'set_status' then update_status(conversation)
    when 'create_private_note' then create_message(conversation, private: true)
    when 'send_public_message' then create_message(conversation, private: false)
    when 'assign_agent' then assign_agent(conversation)
    when /\Afollow_up_/ then update_follow_up(conversation)
    end
  end

  def update_follow_up(conversation)
    operation = @action.delete_prefix('follow_up_')
    GlobalAiAssistant::FollowUpAdapter.new(
      account: @account,
      conversation: conversation,
      operation: operation,
      job_id: @params['job_id'],
      hours: @params['hours']
    ).call
  end

  def update_labels(conversation, add: nil, remove: nil)
    value = (add || remove).to_s.strip
    raise ArgumentError, 'Etiqueta é obrigatória.' if value.blank?

    labels = conversation.label_list
    if add
      title = @account.labels.find { |label| label_key(label.title) == label_key(value) }&.title
      raise ArgumentError, 'Etiqueta não encontrada.' if title.blank?

      labels = (labels + [title]).uniq
    else
      labels = labels.reject { |label| label_key(label) == label_key(value) }
    end
    conversation.update_labels(labels)
    { labels: conversation.label_list }
  end

  def update_status(conversation)
    status = @params['status'].to_s
    raise ArgumentError, 'Status inválido.' unless ALLOWED_STATUSES.include?(status)

    conversation.update!(status: status)
    { status: conversation.status }
  end

  def create_message(conversation, private:)
    content = @params['content'].to_s.strip
    raise ArgumentError, 'Texto é obrigatório.' if content.blank?

    message = Messages::MessageBuilder.new(
      @user,
      conversation,
      ActionController::Parameters.new(content: content, private: private)
    ).perform
    { message_id: message.id, private: message.private? }
  end

  def assign_agent(conversation)
    agent = @account.agents.find(@params['agent_id'])
    conversation.update!(assignee: agent)
    { assignee_id: agent.id, assignee_name: agent.name }
  end

  def label_key(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]/, '')
  end

  def record_audit!(conversation, before_state, result)
    return unless defined?(Enterprise::AuditLog)

    Enterprise::AuditLog.create!(
      action: 'global_ai_action',
      auditable: conversation,
      associated: @account,
      user: @user,
      username: @user.email,
      audited_changes: {
        source: 'global_ai_assistant',
        action: @action,
        conversation_display_id: conversation.display_id,
        before: before_state,
        after: { labels: conversation.label_list, status: conversation.status, assignee_id: conversation.assignee_id },
        result: result
      }.deep_stringify_keys
    )
  end
end
