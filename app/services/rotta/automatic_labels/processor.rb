class Rotta::AutomaticLabels::Processor
  CONTACT_STAGES = %w[primeiro-contato segundo-contato terceiro-contato ultimo-contato contato-instantaneo].freeze
  BUDGET_STAGES = %w[kelvin orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3 orcamento-tentativa-4
                     orcamento-5-dias orcamento-10-dias orcamento-instantaneo].freeze
  HUMAN_NEED = /\b(valor|pre[cç]o|quanto|or[cç]amento final|c[aá]lculo final|proposta final|pagamento|pix|boleto|cart[aã]o|parcel|contrat|fechar|fechamento|reserv|agend|disponibil|data|coleta|entrega|reclam|problema|urgent|desconto|caro|barato|humano|atendente|setor)\b/i

  def initialize(message)
    @message = message
    @conversation = message.conversation
    @account = message.account
    @settings = Rotta::AutomaticLabels::Settings.for(@account)
  end

  def perform
    return unless @conversation && @account

    apply_first_contact if @settings['first_contact'] && incoming?
    apply_kelvin if @settings['kelvin'] && outgoing? && pre_budget?(@message.content)
    apply_caio_attention if @settings['caio_attention'] && incoming?
  rescue StandardError => e
    record('processor', 'failed', e.message, error_class: e.class.name)
    raise
  end

  private

  def incoming?
    @message.message_type == 'incoming' && @message.content_type == 'text'
  end

  def outgoing?
    @message.message_type == 'outgoing' && @message.content_type == 'text'
  end

  def apply_first_contact
    return record('first_contact', 'skipped', nil, reason: 'not_first_inbound') if prior_incoming_exists?

    mutate_labels('first_contact', add: 'primeiro-contato')
  end

  def apply_kelvin
    mutate_labels('kelvin', add: 'kelvin', remove: 'primeiro-contato')
  end

  def apply_caio_attention
    return record('caio_attention', 'skipped', nil, reason: 'no_human_need') unless @message.content.to_s.match?(HUMAN_NEED)

    @conversation.with_lock do
      labels = canonical_labels
      return record('caio_attention', 'blocked', nil, reason: 'contact_trail') if (labels & CONTACT_STAGES).any?
      return record('caio_attention', 'blocked', nil, reason: 'outside_budget_trail') if (labels & BUDGET_STAGES).empty?

      mutate_labels_locked('caio_attention', add: 'caio-atencao')
    end
  end

  def prior_incoming_exists?
    @account.messages
            .where(message_type: :incoming, sender_type: 'Contact', sender_id: @conversation.contact_id)
            .where.not(id: @message.id)
            .exists?
  end

  def mutate_labels(key, add:, remove: nil)
    @conversation.with_lock do
      mutate_labels_locked(key, add:, remove:)
    end
  end

  def mutate_labels_locked(key, add:, remove: nil)
    current = @conversation.label_list.to_a
    add_title = account_label_title(add)
    raise "Etiqueta #{add} não foi encontrada nesta conta." unless add_title

    updated = (current + [add_title]).uniq
    if remove
      remove_title = account_label_title(remove)
      updated -= [remove_title] if remove_title
    end
    return record(key, 'no_op', nil, labels: current) if updated.sort == current.sort

    @conversation.update_labels(updated)
    @conversation.reload
    unless @conversation.label_list.include?(add_title) && (!remove || remove_title.nil? || !@conversation.label_list.include?(remove_title))
      raise 'A confirmação autoritativa das etiquetas falhou.'
    end

    record(key, 'applied', nil, labels: @conversation.label_list)
  end

  def account_label_title(slug)
    @account.labels.find { |label| canonical(label.title) == slug }&.title
  end

  def canonical_labels
    @conversation.label_list.map { |label| canonical(label) }
  end

  def canonical(value)
    I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
  end

  def pre_budget?(content)
    text = I18n.transliterate(content.to_s).upcase.tr('–—−', '-').gsub(/[*_~]/, ' ')
    return false unless text.match?(/PRE\s*[- ]?\s*ORCAMENTO|PREORCAMENTO/)

    required_fields = [
      /ORIGEM(?: DA MUDANCA)?\s*[:\-]\s*.+?DESTINO/m,
      /DESTINO(?: DA MUDANCA)?\s*[:\-]\s*.+?(?:INVENTARIO|ITENS|LISTA DE ITENS)/m,
      /(?:INVENTARIO|ITENS|LISTA DE ITENS)\s*[:\-]?\s*.+?(?:EQUIPE|AJUDANTES?|SERVICOS?|PAGAMENTO)/m
    ]
    team_signals = %w[EQUIPE AJUDANTE CARGA DESCARGA].count { |term| text.include?(term) }
    service_signal = %w[SERVICO DESMONTAGEM MONTAGEM].any? { |term| text.include?(term) }
    required_fields.all? { |pattern| text.match?(pattern) } && team_signals >= 2 && service_signal &&
      text.include?('PAGAMENTO') && text.scan(/\b\d{1,3}\s*%/).length >= 2
  end

  def record(key, status, error = nil, metadata = {})
    RottaAutomaticLabelLog.create_with(
      account: @account, conversation: @conversation, message: @message,
      automation_key: key, status: status, error_message: error, metadata: metadata
    ).find_or_create_by!(account: @account, event_key: "#{@message.id}:#{key}")
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
