require 'json'

class ConversationAi::ProfileService
  PROFILE_KEY = 'rotta_move_profile'.freeze
  MODEL = GlobalAiAssistant::ProviderConfig::MODEL
  PROFILE_FIELDS = %w[
    origin destination move_date budget_value items observations
    helpers_origin helpers_destination assembly_items disassembly_items
  ].freeze
  INTEGER_FIELDS = %w[helpers_origin helpers_destination].freeze
  EMPTY_VALUES = ['não informado', 'nao informado', 'não consta', 'nao consta', 'null', 'n/a'].freeze

  def initialize(conversation:, user:)
    @conversation = conversation
    @user = user
    @contact = conversation.contact
  end

  def call
    raise ArgumentError, 'O contato da conversa não está disponível.' if @contact.blank?

    messages = conversation_messages
    extracted = parse_response(ask_model(messages))
    profile = existing_profile
    changed_fields = []

    PROFILE_FIELDS.each do |field|
      value = normalise_field(field, extracted.dig('profile', field))
      next if value.nil? || !valid_evidence?(field, extracted.dig('evidence', field), messages)
      next if profile[field].to_s == value.to_s

      profile[field] = value
      changed_fields << field
    end

    contact_name = normalise_name(extracted['contact_name'])
    name_changed = contact_name.present? && contact_name != @contact.name.to_s.strip &&
                   valid_evidence?('contact_name', extracted.dig('evidence', 'contact_name'), messages)

    if changed_fields.present? || name_changed
      @contact.update!(
        name: name_changed ? contact_name : @contact.name,
        custom_attributes: (@contact.custom_attributes || {}).merge(PROFILE_KEY => profile)
      )
      record_audit!(profile, changed_fields, contact_name, name_changed)
    end

    {
      ok: true,
      contact: { id: @contact.id, name: @contact.name },
      profile: profile,
      changed_fields: changed_fields,
      contact_name_changed: name_changed,
      evidence: extracted['evidence'].is_a?(Hash) ? extracted['evidence'] : {},
      message_count: messages.length
    }
  end

  private

  def conversation_messages
    @conversation.messages
                 .where.not(message_type: [:activity, :template])
                 .includes(:sender)
                 .order(created_at: :asc)
                 .map do |message|
      {
        id: message.id,
        created_at: message.created_at.iso8601,
        content: message.content_for_llm.to_s,
        sender: sender_label(message)
      }
    end
  end

  def sender_label(message)
    label = case message.sender_type
            when 'User' then 'agente humano'
            when 'Contact' then 'cliente'
            else 'bot'
            end
    message.private? ? "nota privada / #{label}" : label
  end

  def ask_model(messages)
    api_key = GlobalAiAssistant::ProviderConfig.api_key
    raise ArgumentError, 'A credencial DeepSeek/OpenRouter da IA global não está configurada.' if api_key.blank?

    GlobalAiAssistant::OpenRouterClient.new(
      api_key: api_key,
      api_base: GlobalAiAssistant::ProviderConfig.api_base
    ).call([
      { role: 'system', content: system_prompt },
      { role: 'user', content: JSON.generate({
        current_contact_name: @contact.name,
        current_profile: existing_profile,
        conversation_messages: messages
      }) }
    ])
  end

  def system_prompt
    <<~PROMPT
      Você é o extrator operacional do perfil de mudança da Rotta Brasil Express.
      Trabalhe somente com a conversa atual fornecida no JSON. Não use conhecimento externo,
      outra conversa ou suposição. A resposta deve ser SOMENTE um objeto JSON válido, sem markdown.

      Leia toda a cronologia. Quando houver versões conflitantes de um dado, use a declaração
      explícita mais recente do cliente ou da equipe. Não substitua um dado atual por vazio,
      "não informado" ou uma inferência. Se um campo não tiver evidência explícita, retorne null.
      Para cada campo não nulo, informe em evidence uma mensagem existente e uma citação literal
      curta dessa mensagem. A citação precisa ser copiável do conteúdo da mensagem.
      O nome só pode ser alterado quando o nome real estiver explicitamente informado na conversa.
      Inclua notas privadas no raciocínio, mas não invente informação a partir delas.

      O JSON obrigatório tem este formato:
      {
        "contact_name": string|null,
        "profile": {
          "origin": string|null,
          "destination": string|null,
          "move_date": string|null,
          "budget_value": string|null,
          "items": string|null,
          "observations": string|null,
          "helpers_origin": integer|null,
          "helpers_destination": integer|null,
          "assembly_items": string|null,
          "disassembly_items": string|null
        },
        "evidence": {
          "contact_name": {"message_id": integer, "quote": string},
          "origin": {"message_id": integer, "quote": string}
        }
      }

      Repita em evidence apenas os campos realmente preenchidos. Não preencha com zero quando
      a quantidade de ajudantes não estiver explícita. Preserve acentos e valores exatamente como
      aparecem na conversa. O campo items pode ser uma lista compacta, mas deve ser suportado por
      uma ou mais citações textuais existentes.
    PROMPT
  end

  def parse_response(content)
    raw = content.to_s.strip
    raw = raw.gsub(/\A```(?:json)?\s*/i, '').gsub(/\s*```\z/, '')
    parsed = JSON.parse(raw)
    raise ArgumentError, 'A IA retornou um formato de perfil inválido.' unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError
    raise ArgumentError, 'A IA não retornou o perfil em JSON válido.'
  end

  def existing_profile
    attributes = @contact.custom_attributes || {}
    stored = attributes[PROFILE_KEY] || attributes['rottaMoveProfile'] || {}
    stored.is_a?(Hash) ? stored.deep_stringify_keys : {}
  end

  def normalise_field(field, value)
    return nil if value.nil?

    if INTEGER_FIELDS.include?(field)
      number = value.is_a?(Numeric) ? value.to_i : (Integer(value.to_s, 10) rescue nil)
      return nil if number.nil? || number.negative? || number > 99

      return number
    end

    text = value.to_s.strip
    return nil if text.blank? || EMPTY_VALUES.include?(text.downcase)

    text.truncate(8000)
  end

  def normalise_name(value)
    text = value.to_s.strip
    return nil if text.blank? || EMPTY_VALUES.include?(text.downcase) || text.length > 120

    text
  end

  def valid_evidence?(field, evidence, messages)
    return false unless evidence.is_a?(Hash)

    message = messages.find { |item| item[:id].to_s == evidence['message_id'].to_s }
    quote = evidence['quote'].to_s.strip
    return false if message.blank? || quote.blank?

    collapsed_quote = collapse_text(quote)
    collapsed_content = collapse_text(message[:content])
    collapsed_content.include?(collapsed_quote)
  end

  def collapse_text(value)
    I18n.transliterate(value.to_s).downcase.gsub(/\s+/, ' ').strip
  end

  def record_audit!(profile, changed_fields, contact_name, name_changed)
    return unless defined?(Enterprise::AuditLog)

    Enterprise::AuditLog.create!(
      action: 'conversation_ai_profile',
      auditable: @conversation,
      associated: @conversation.account,
      user: @user,
      username: @user&.email,
      audited_changes: {
        source: 'conversation_ai_profile',
        conversation_display_id: @conversation.display_id,
        contact_id: @contact.id,
        changed_fields: changed_fields,
        contact_name_changed: name_changed,
        contact_name: contact_name,
        profile: profile
      }.deep_stringify_keys
    )
  end
end
