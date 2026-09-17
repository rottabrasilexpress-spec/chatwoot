class GlobalAiAssistant::ContextBuilder
  MAX_CARDS = 40
  MAX_FOLLOW_UP_CARDS = 12
  MAX_FOLLOW_UP_SOURCE_MESSAGES = 12
  MAX_MESSAGES_PER_CONVERSATION = 8
  MAX_FOLLOW_UP_MESSAGES = 3
  MAX_DETAILED_MESSAGES = 80
  FOLLOW_UP_QUERY = /follow[\s-]?up|lembrete|etiqueta|primeiro contato|segundo contato|terceiro contato|orçamento|orcamento|pendên|penden/i.freeze
  OPERATIONAL_QUERY = /cliente|contato|conversa|follow[\s-]?up|lembrete|etiqueta|status|relat[oó]rio|pendên|penden|financeir|orçamento|orcamento|hist[oó]rico|mensagem|telefone|quem|quantos|qual/i.freeze
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
    return scope.none unless operational_question?
    return scope.limit(MAX_CARDS) if question.blank?
    return scope.limit(MAX_FOLLOW_UP_CARDS) if follow_up_question?

    merged_ids = matching_conversation_ids(scope)
    return scope.where(id: merged_ids).order(last_activity_at: :desc) if merged_ids.present?

    scope.none
  end

  def matching_conversation_ids(scope)
    query = searchable_query
    contact_ids = matching_contacts(scope, query).limit(MAX_CARDS).pluck(:id)
    message_ids = account.messages
                         .where('content ILIKE ?', "%#{query}%")
                         .order(created_at: :desc)
                         .limit(80)
                         .pluck(:conversation_id)
    (contact_ids + message_ids).uniq.first(MAX_CARDS)
  end

  def searchable_query
    email = question.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)&.to_s
    return ActiveRecord::Base.sanitize_sql_like(email) if email.present?

    phone = question.scan(/\+?\d[\d\s().-]{8,}\d/).map { |value| value.gsub(/\D/, '') }.find { |value| value.length >= 10 }
    return ActiveRecord::Base.sanitize_sql_like(phone) if phone.present?

    ActiveRecord::Base.sanitize_sql_like(question)
  end

  def matching_contacts(scope, query)
    if query.match?(/\A\d{8,}\z/)
      return scope.joins(:contact).where(
        "regexp_replace(contacts.phone_number, '[^0-9]', '', 'g') LIKE :query",
        query: "%#{query}%"
      )
    end

    scope.joins(:contact).where(
      'contacts.name ILIKE :query OR contacts.email ILIKE :query OR contacts.phone_number ILIKE :query',
      query: "%#{query}%"
    )
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
      follow_up_jobs: follow_up_jobs_for(conversation.display_id),
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
    return MAX_FOLLOW_UP_MESSAGES if follow_up_question?

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
    end.first(follow_up_question? ? MAX_FOLLOW_UP_SOURCE_MESSAGES : 80)
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
    cached_labels = account.conversations
                            .where.not(status: :resolved)
                            .pluck(:cached_label_list)
                            .flat_map { |labels| labels.to_s.split(',').map(&:strip).compact_blank }

    {
      total_conversations: account.conversations.count,
      by_status: statuses,
      active: account.conversations.where.not(status: :resolved).count,
      follow_up_labels: cached_labels.tally.select do |label, _count|
        FOLLOW_UP_LABEL_KEYS.include?(label_key(label))
      end,
      follow_up_jobs: follow_up_jobs
    }
  end

  def follow_up_jobs
    return { available: false, reason: 'not_requested' } unless follow_up_question?

    payload = follow_up_payload
    jobs = Array(payload['jobs']).first(120)
    {
      available: payload['available'] != false,
      config: payload['config'] || payload['meta'] || {},
      labels: payload['labels'] || {},
      timezone: payload['timezone'],
      jobs: jobs.map do |job|
        job.slice(
          'job_id', 'conversation_id', 'customer_name', 'phone', 'current_label',
          'source_label', 'next_label', 'status', 'scheduled_at', 'history',
          'active_labels'
        )
      end
    }
  end

  def follow_up_payload
    @follow_up_payload ||= GlobalAiAssistant::FollowUpAdapter.list
  end

  def follow_up_jobs_for(conversation_id)
    return [] unless follow_up_question?

    Array(follow_up_payload['jobs']).select do |job|
      job['conversation_id'].to_s == conversation_id.to_s
    end.first(10).map do |job|
      job.slice(
        'job_id', 'conversation_id', 'customer_name', 'phone', 'current_label',
        'source_label', 'next_label', 'status', 'scheduled_at', 'history',
        'active_labels'
      )
    end
  end

  def follow_up_question?
    question.match?(FOLLOW_UP_QUERY)
  end

  def operational_question?
    question.match?(OPERATIONAL_QUERY)
  end
end
