class GlobalAiAssistant::ContextBuilder
  MAX_CARDS = 40
  MAX_MESSAGES_PER_CONVERSATION = 8
  MAX_DETAILED_MESSAGES = 80
  FOLLOW_UP_LABEL_KEYS = %w[
    primeiro-contato segundo-contato terceiro-contato ultimo-contato
    orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3 orcamento-tentativa-4
    orcamento-5-dias orcamento-10-dias orcamento-15-dias kelvin-caio
  ].freeze

  def initialize(account:, question:)
    @account = account
    @question = question.to_s.strip
  end

  def call
    conversations = matching_conversations
    {
      question: @question,
      generated_at: Time.current.iso8601,
      reports: report_snapshot,
      cards: conversations.first(MAX_CARDS).map { |conversation| card_for(conversation) },
      source_messages: source_messages(conversations)
    }
  end

  private

  attr_reader :account, :question

  def matching_conversations
    scope = account.conversations.includes(:contact, :inbox).order(last_activity_at: :desc)
    return scope.limit(MAX_CARDS) if question.blank?

    query = ActiveRecord::Base.sanitize_sql_like(question)
    contact_matches = scope.joins(:contact).where(
      'contacts.name ILIKE :query OR contacts.email ILIKE :query OR contacts.phone_number ILIKE :query',
      query: "%#{query}%"
    )
    message_ids = account.messages.where('content ILIKE ?', "%#{query}%").order(created_at: :desc).limit(80).pluck(:conversation_id)
    merged_ids = (contact_matches.limit(MAX_CARDS).pluck(:id) + message_ids).uniq.first(MAX_CARDS)
    return scope.where(id: merged_ids).order(last_activity_at: :desc) if merged_ids.present?

    scope.limit(MAX_CARDS)
  end

  def card_for(conversation)
    recent_messages = conversation.messages
                                  .where(message_type: [:incoming, :outgoing])
                                  .where(private: false)
                                  .order(id: :desc)
                                  .limit(message_limit_for(conversation))
                                  .to_a
                                  .reverse
    last_message = recent_messages.last
    evidence = pending_evidence(recent_messages)

    {
      conversation_id: conversation.display_id,
      customer_name: conversation.contact&.name.presence || 'Cliente sem nome',
      phone: conversation.contact&.phone_number,
      email: conversation.contact&.email,
      status: conversation.status,
      labels: conversation.label_list,
      follow_up_stage: follow_up_stage(conversation.label_list),
      last_activity_at: conversation.last_activity_at&.iso8601,
      last_message: last_message&.content.to_s.truncate(240),
      recent_history: recent_messages.map do |message|
        {
          created_at: message.created_at.iso8601,
          role: message.incoming? ? 'cliente' : 'equipe',
          content: message.content.to_s.truncate(600)
        }
      end,
      evidence: evidence,
      open_url: "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    }
  end

  def message_limit_for(conversation)
    identifiers = [conversation.contact&.name, conversation.contact&.email, conversation.contact&.phone_number]
                  .compact
                  .map(&:to_s)
                  .reject { |value| value.length < 4 }
    identifiers.any? { |identifier| question.downcase.include?(identifier.downcase) } ? MAX_DETAILED_MESSAGES : MAX_MESSAGES_PER_CONVERSATION
  end

  def source_messages(conversations)
    conversations.flat_map do |conversation|
      conversation.messages
                  .where(message_type: [:incoming, :outgoing])
                  .where(private: false)
                  .where(
                    'content ILIKE :finance OR content ILIKE :waiting OR content ILIKE :return OR content ILIKE :document',
                    finance: '%financeir%',
                    waiting: '%aguard%',
                    return: '%retorn%',
                    document: '%document%'
                  )
                  .order(created_at: :desc)
                  .limit(3)
                  .map do |message|
        {
          conversation_id: conversation.display_id,
          created_at: message.created_at.iso8601,
          role: message.incoming? ? 'cliente' : 'equipe',
          content: message.content.to_s.truncate(320)
        }
      end
    end.first(80)
  end

  def pending_evidence(messages)
    candidate = messages.reverse.find do |message|
      message.content.to_s.match?(/financeir|aguard|retorn|penden|document|orçamento|orcamento/i)
    end
    return nil unless candidate

    {
      created_at: candidate.created_at.iso8601,
      role: candidate.incoming? ? 'cliente' : 'equipe',
      content: candidate.content.to_s.truncate(320),
      reason: pending_reason(candidate.content)
    }
  end

  def pending_reason(content)
    text = content.to_s.downcase
    return 'aguardando financeiro' if text.match?(/financeir/)
    return 'aguardando retorno' if text.match?(/aguard|retorn|responder/)
    return 'aguardando documento' if text.match?(/document|arquivo|pdf|lista/)

    'pendência identificada no último contexto'
  end

  def follow_up_stage(labels)
    Array(labels).find do |label|
      FOLLOW_UP_LABEL_KEYS.include?(label_key(label))
    end
  end

  def label_key(label)
    I18n.transliterate(label.to_s).downcase.gsub(/[^a-z0-9]+/, '-')
  end

  def report_snapshot
    statuses = account.conversations.group(:status).count
    {
      total_conversations: account.conversations.count,
      by_status: statuses,
      active: account.conversations.where.not(status: :resolved).count,
      follow_up_labels: account.conversations
                                  .where.not(status: :resolved)
                                  .flat_map(&:label_list)
                                  .tally
                                  .select { |label, _count| FOLLOW_UP_LABEL_KEYS.include?(label_key(label)) }
    }
  end
end
