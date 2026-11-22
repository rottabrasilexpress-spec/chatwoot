class ConversationAi::ProfileContextBuilder
  MAX_CONTEXT_CHARACTERS = 24_000
  MAX_MESSAGE_CHARACTERS = 2_400
  RELEVANCE_TERMS = %w[
    origem destino cidade estado mudança mudanca coleta data valor orçamento orcamento
    item itens móvel moveis móveis caixa caixas ajudante montagem desmontagem
    elevador escada acesso distância distancia rota pagamento carga descarga
  ].freeze

  def initialize(conversation:, messages: nil, character_limit: MAX_CONTEXT_CHARACTERS, focus_terms: [], recent_count: 12, include_transcripts: false)
    @conversation = conversation
    @messages = messages
    @character_limit = character_limit
    @focus_terms = focus_terms
    @recent_count = recent_count
    @include_transcripts = include_transcripts
  end

  def call
    candidates = text_messages
    selected = select_messages(candidates)
    selected_for_model = selected.map { |message| message.except(:score) }

    {
      messages: selected_for_model,
      metrics: {
        message_count: candidates.length,
        selected_message_count: selected_for_model.length,
        input_characters: candidates.sum { |message| message[:content].length },
        selected_characters: selected_for_model.sum { |message| message[:content].length },
        truncated: selected_for_model.length < candidates.length
      }
    }
  end

  private

  def text_messages
    transcripts = @include_transcripts && @messages.nil? ? saved_transcripts : {}
    source_messages.filter_map do |message|
      content = compact_content((message.content.presence || transcripts[message.id]).to_s.strip)
      next if content.blank?

      {
        id: message.id,
        created_at: message.created_at.iso8601,
        content: content,
        sender: sender_label(message),
        score: relevance_score(content)
      }
    end
  end

  def saved_transcripts
    voice_messages = @conversation.messages.where(content: [nil, '']).select(:id)
    Attachment.where(message_id: voice_messages, file_type: :audio)
              .where("meta->>'transcribed_text' IS NOT NULL").order(:id)
              .pluck(:message_id, Arel.sql("meta->>'transcribed_text'")).group_by(&:first)
              .transform_values { |parts| "[Áudio transcrito] #{parts.map(&:last).join(' ')}" }
  end

  def source_messages
    return Array(@messages).sort_by { |message| [message.created_at, message.id] } if @messages

    @conversation.messages
                .select(:id, :content, :created_at, :message_type, :sender_type, :private)
                .where.not(message_type: [:activity, :template])
                .reorder(created_at: :asc, id: :asc)
  end

  def compact_content(content)
    return content if content.length <= MAX_MESSAGE_CHARACTERS

    head_length = 1_400
    tail_length = MAX_MESSAGE_CHARACTERS - head_length - 35
    "#{content.first(head_length)}\n...[trecho omitido]...\n#{content.last(tail_length)}"
  end

  def sender_label(message)
    label = case message.sender_type
            when 'User' then 'agente humano'
            when 'Contact' then 'cliente'
            else 'bot'
            end
    message.private? ? "nota privada / #{label}" : label
  end

  def select_messages(candidates)
    return candidates if total_characters(candidates) <= @character_limit

    protected_ids = candidates.first(4).concat(candidates.last(@recent_count)).map { |message| message[:id] }.to_set
    ranked = candidates.sort_by do |message|
      [-(message[:score] + (protected_ids.include?(message[:id]) ? 2 : 0)), -message[:created_at].to_time.to_i]
    end

    selected = []
    characters = 0
    ranked.each do |message|
      next if characters + message[:content].length > @character_limit

      selected << message
      characters += message[:content].length
    end

    selected.sort_by { |message| [message[:created_at], message[:id]] }
  end

  def total_characters(messages)
    messages.sum { |message| message[:content].length }
  end

  def relevance_score(content)
    normalized = I18n.transliterate(content.downcase)
    RELEVANCE_TERMS.count { |term| normalized.include?(I18n.transliterate(term)) } +
      2 * @focus_terms.count { |term| normalized.include?(term) }
  end
end
