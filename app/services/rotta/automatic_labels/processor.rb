class Rotta::AutomaticLabels::Processor
  CONTACT_STAGES = %w[primeiro-contato segundo-contato terceiro-contato ultimo-contato contato-instantaneo].freeze
  BUDGET_STAGES = %w[kelvin orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3 orcamento-tentativa-4
                     orcamento-5-dias orcamento-10-dias orcamento-15-dias orcamento-instantaneo].freeze
  CAIO_MIN_CONFIDENCE = 0.80
  POST_BUDGET_INTEREST_TOPIC = /\b(valor(?:es)?|pre[cç]os?|desconto|pagamento|[aà] vista|parcel\w*|prazo|entrega|coleta|datas?|disponibil\w*|ajudantes?|servi[cç]os?|montagem|desmontagem|inclu\w*|contrat\w*|reserv\w*)\b/i
  POST_BUDGET_INTEREST_REQUEST = /\?|\b(qual|quais|quanto|quando|como|pode|posso|consigo|tem|h[aá]|queria|gostaria|quero|preciso|d[uú]vida|saber|confirma\w*)\b/i
  REVISION_ACTION = /\b(?:(?:atualiz|recalcul|retific|revis|reajust|alter|ajust|renov|melhor)(?:a|ar|e|em|aria|asse|ao)|refaz(?:er|a)?|refaca|corrig(?:ir|e)|corrija)\b/
  QUOTE_TOPIC = /\b(?:orcamentos?|cotacao|proposta|precos?|valor(?:es)?|frete|custos?|taxas?)\b/
  PRICE_REQUEST = /\b(?:quanto (?:fica|sai|custa)|(?:qual|saber|passar|mandar|informar|dizer) (?:seria |tambem )?(?:o |a )?#{QUOTE_TOPIC})/
  EXTRA_PRICE = /\b(?:adiciona\w*|inclu\w*|acrescenta\w*|junto|a mais|com mais|se (?:eu |a gente )?(?:colocar|tirar|levar|trocar))\b/
  SCOPE_TOPIC = /\b(?:ajudantes?|montagem|desmontagem|embalagem|inventario|itens?|moveis|caixas?|moto|data|origem|destino|endereco|rota)\b/
  SCOPE_CHANGE = /\b(?:(?:inclu|adicion|acrescent|retir|remov|troc|mud)(?:a|ar|e|er|ir|ua)|tirar|colocar|(?:agora|tambem) (?:vou precisar|preciso|quero))\b/
  NEW_QUOTE = /\b(?:novo orcamento|nova cotacao|nova proposta|recalcular|recalcula|recalcule)\b/
  DECLINED_REVISION = /\bnao (?:(?:precis[ao]|quero|gostaria|vamos|pode|e necessario|e para) (?:de (?:um |uma )?)?)?(?:#{REVISION_ACTION}|#{NEW_QUOTE})/
  REVISION_LABELS = { 'kelvin' => 'kelvin', 'caio_attention' => 'caio-atencao' }.freeze
  QUOTE_HEADING = '(^|\n)[[:space:][:punct:]]*(or[çc]amento[[:space:]]+final|proposta[[:space:]]+(comercial|final))([[:space:][:punct:]]|$)'
  QUOTE_DIRECT = '(^|\n)[[:space:][:punct:]]*((o|seu)[[:space:]]+)?(valor( total)? (do|da) (frete|transporte|mudan[çc]a)[[:space:]]*(:|[ée] |fica |sai )|(frete|transporte|mudan[çc]a) (fica|sai) )'

  def initialize(message)
    @message = message
    @conversation = message.conversation
    @account = message.account
    @settings = Rotta::AutomaticLabels::Settings.for(@account)
  end

  def perform
    return unless @conversation && @account
    return if incoming? && !@message.private? && apply_budget_revision

    apply_first_contact if @settings['first_contact'] && incoming?
    apply_kelvin if @settings['kelvin'] && outgoing? && pre_budget?(@message.content)
    apply_caio_attention if @settings['caio_attention'] && incoming? && !@message.private?
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

  def apply_budget_revision
    additions = REVISION_LABELS.filter_map { |key, label| label if @settings[key] }
    return false if additions.empty? || !budget_revision_requested?

    @conversation.with_lock do
      labels = canonical_labels
      final_quote = @conversation.messages.outgoing.where(private: false, content_type: :text).where.not(status: :failed)
                                 .where('content ~* ?', 'or[çc]amento final[[:space:]]*[-—][[:space:]]*rotta')
                                 .reorder(created_at: :desc, id: :desc).pick(:created_at, :id)
      next false if (labels & BUDGET_STAGES).empty? && final_quote.nil?
      # A delayed or replayed event must not reopen a revision already superseded by a final quote.
      next true if final_quote && (final_quote <=> [@message.created_at, @message.id]).positive?
      next true if @account.rotta_automatic_label_logs.exists?(event_key: "#{@message.id}:budget_revision")

      if additions.include?('caio-atencao') &&
         ((labels & CONTACT_STAGES).any? || (labels & BUDGET_STAGES).empty? || !quote_received_before_message?)
        additions.delete('caio-atencao')
      end
      next false if additions.empty?

      mutate_labels_locked('budget_revision', add: additions)
      true
    end
  end

  def budget_revision_requested?
    text = I18n.transliterate(@message.content.to_s).downcase
    text.scan(/[^.!;?\n]+\??/).any? do |part|
      next false if part.match?(DECLINED_REVISION)

      price = part.match?(QUOTE_TOPIC)
      scope = part.match?(SCOPE_TOPIC)
      request = part.match?(POST_BUDGET_INTEREST_REQUEST)
      revision = part.match?(REVISION_ACTION) && (price || scope)
      updated_quote = price && part.match?(/\b(?:mande|envie|quero|preciso|gostaria|consegue|pode)\b.*\b(?:atualizad|revisad|recalculad)[oa]\b/)
      extra_cost = part.match?(PRICE_REQUEST) && (part.match?(EXTRA_PRICE) || (scope && part.match?(/\b(?:com|sem|se)\b/)))
      scope_change = request && scope && part.match?(SCOPE_CHANGE)
      revision || updated_quote || part.match?(NEW_QUOTE) || extra_cost || scope_change
    end
  end

  def apply_caio_attention
    decision_kind = caio_decision_kind
    return record('caio_attention', 'skipped', nil, reason: 'no_human_need') if decision_kind == :none

    reservation = nil
    @conversation.with_lock do
      labels = canonical_labels
      return record('caio_attention', 'blocked', nil, reason: 'contact_trail') if (labels & CONTACT_STAGES).any?
      return record('caio_attention', 'blocked', nil, reason: 'outside_budget_trail') if (labels & BUDGET_STAGES).empty?
      return record('caio_attention', 'no_op', nil, reason: 'already_applied') if labels.include?('caio-atencao')
      return record('caio_attention', 'blocked', nil, reason: 'budget_delivery_unconfirmed') unless quote_received_before_message?

      reservation = reserve_caio_event
    end

    return unless reservation

    decision = caio_decision(decision_kind)
    unless decision.needs_human? && decision.confidence >= CAIO_MIN_CONFIDENCE
      finalize_caio_event(reservation, 'skipped', confidence: decision.confidence, reason: decision.reason)
      return
    end

    @conversation.with_lock do
      labels = canonical_labels
      if (labels & CONTACT_STAGES).any?
        finalize_caio_event(reservation, 'blocked', reason: 'contact_trail_after_classification')
      elsif (labels & BUDGET_STAGES).empty?
        finalize_caio_event(reservation, 'blocked', reason: 'outside_budget_trail_after_classification')
      elsif !quote_received_before_message?
        finalize_caio_event(reservation, 'blocked', reason: 'budget_delivery_unconfirmed_after_classification')
      else
        mutate_labels_locked('caio_attention', add: 'caio-atencao')
        finalize_caio_event(reservation, 'applied', confidence: decision.confidence, reason: decision.reason)
      end
    end
  rescue Rotta::AutomaticLabels::HumanNeedClassifier::Error => e
    finalize_caio_event(reservation, 'failed', error_message: e.message) if reservation
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
    add_titles = Array(add).map do |slug|
      account_label_title(slug) || raise("Etiqueta #{slug} não foi encontrada nesta conta.")
    end

    updated = (current + add_titles).uniq
    if remove
      remove_title = account_label_title(remove)
      updated -= [remove_title] if remove_title
    end
    return record(key, 'no_op', nil, labels: current) if updated.sort == current.sort

    @conversation.update_labels(updated)
    @conversation.reload
    unless (add_titles - @conversation.label_list).empty? && (!remove_title || !@conversation.label_list.include?(remove_title))
      raise 'A confirmação autoritativa das etiquetas falhou.'
    end

    record(key, 'applied', nil, labels: @conversation.label_list)
  end

  def reserve_caio_event
    @account.rotta_automatic_label_logs.create!(
      account: @account,
      conversation: @conversation,
      message: @message,
      automation_key: 'caio_attention',
      status: 'processing',
      event_key: "#{@message.id}:caio_attention",
      metadata: { 'model' => Rotta::AutomaticLabels::HumanNeedClassifier::MODEL }
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil
  end

  def finalize_caio_event(log, status, error_message: nil, **metadata)
    log.update!(status:, error_message:, metadata: log.metadata.to_h.merge(metadata.stringify_keys))
  end

  def llm_context
    {
      last_message: @message.content.presence || 'O cliente enviou um anexo sem legenda.',
      recent_messages: prior_messages.where(private: false, message_type: [:incoming, :outgoing]).where.not(status: :failed)
                                     .reorder(created_at: :desc, id: :desc).limit(6).to_a.reverse.map do |message|
        {
          role: message.message_type == 'incoming' ? 'cliente' : 'empresa',
          content: message.content.to_s
        }
      end
    }
  end

  def caio_decision_kind
    return :ambiguous if @message.content.blank? && @message.attachments.where(file_type: [:file, :image]).exists?

    Rotta::AutomaticLabels::CommercialIntent.classify(@message.content)
  end

  def caio_decision(kind)
    if kind == :ambiguous
      context = llm_context
      unless Rotta::AutomaticLabels::CommercialIntent.confirmed_by_context?(context)
        return Rotta::AutomaticLabels::HumanNeedClassifier.new.call(context)
      end
    end

    Rotta::AutomaticLabels::HumanNeedClassifier::Decision.new(needs_human: true, confidence: 1.0, reason: 'regra_deterministica')
  end

  def prior_messages
    @conversation.messages.where('(messages.created_at, messages.id) < (?, ?)', @message.created_at, @message.id)
  end

  def quote_received_before_message?
    quotes = prior_messages.outgoing.where(private: false)
                           .where('(content ~* ? OR content ~* ?)', QUOTE_HEADING, QUOTE_DIRECT)
                           .where('content ~* ?', 'R[$][[:space:]]*[0-9]')
                           .where('left(content, 150) !~* ?', 'pr[ée][[:space:]‐‑–—-]*or[çc]amento')
    received = quotes.where(status: [:delivered, :read])
    reply_id = @message.in_reply_to_external_id.to_s.presence
    received = received.or(quotes.where(status: :sent, source_id: reply_id)) if reply_id
    received.exists?
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
