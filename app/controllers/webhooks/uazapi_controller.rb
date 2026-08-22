class Webhooks::UazapiController < ActionController::API
  include Events::Types

  ACCOUNT_ID = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  WEBHOOK_TOKEN = ENV.fetch('ROTTABRASIL_UAZAPI_WEBHOOK_TOKEN', 'rotta-uazapi-ack-v1').freeze

  def process_payload
    return render json: { ok: false }, status: :unauthorized unless params[:token].to_s == WEBHOOK_TOKEN

    payload = JSON.parse(request.raw_post.presence || '{}')
    event = extract_event(payload)

    if presence_event?(event)
      return process_presence_event(payload)
    end

    raw_status = extract_status(payload)
    return render json: { ok: true, ignored: 'status ausente' } unless raw_status.present?

    message = find_message(payload)
    return render json: { ok: true, ignored: 'mensagem não localizada' } unless message

    message.update!(message_update_attributes(message, payload, raw_status))
    render json: { ok: true, message_id: message.id, status: message.status }
  rescue JSON::ParserError
    render json: { ok: false, error: 'Payload inválido.' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error("[UazapiWebhook] #{e.class}: #{e.message}")
    render json: { ok: false, error: 'Falha ao processar confirmação Uazapi.' }, status: :unprocessable_entity
  end

  private

  def process_presence_event(payload)
    presence = normalize_presence(extract_presence(payload))
    return render json: { ok: true, ignored: 'presença ausente' } unless presence

    conversation = find_conversation(payload, direct_only: true)
    return render json: { ok: true, ignored: 'conversa não localizada' } unless conversation

    event_name = presence == :on ? CONVERSATION_TYPING_ON : CONVERSATION_TYPING_OFF
    Rails.configuration.dispatcher.dispatch(
      event_name,
      Time.zone.now,
      conversation: conversation,
      user: conversation.contact,
      is_private: false
    )

    render json: { ok: true, event: 'presence', status: presence.to_s, conversation_id: conversation.id }
  end

  def extract_event(payload)
    value_for_keys(payload, %w[event EventType eventType event_name type name]).to_s.downcase
  end

  def presence_event?(event)
    event.include?('presence')
  end

  def extract_presence(payload)
    value_for_keys(payload, %w[presence presenceStatus presence_status state typing_status]).to_s
  end

  def normalize_presence(value)
    normalized = value.to_s.downcase
    return :on if %w[composing typing recording record].any? { |item| normalized.include?(item) }
    return :off if %w[paused pause available unavailable offline].any? { |item| normalized.include?(item) }

    nil
  end

  def find_message(payload)
    provider_ids = extract_provider_ids(payload)
    provider_id_variants = provider_ids.flat_map { |id| [id, "uazapi:#{id}"] }.uniq
    message = Message.where(account_id: ACCOUNT_ID, message_type: Message.message_types[:outgoing])
                     .where(source_id: provider_id_variants)
                     .order(created_at: :desc).first if provider_ids.present?
    return message if message

    conversation = find_conversation(payload)
    return unless conversation

    candidates = conversation.messages
                            .where(message_type: Message.message_types[:outgoing], private: false)
                            .order(created_at: :desc).limit(100)
    return candidates.first unless provider_ids.present?

    candidates.find do |candidate|
      external_ids = candidate.external_source_ids.is_a?(Hash) ? candidate.external_source_ids.values : []
      stored_ids = candidate.additional_attributes.is_a?(Hash) ? candidate.additional_attributes.values : []
      (external_ids + stored_ids + [candidate.source_id]).flat_map { |value| value.is_a?(Array) ? value : [value] }
        .compact.any? { |value| provider_id_matches?(value, provider_id_variants) }
    end
  end

  def provider_id_matches?(value, provider_id_variants)
    candidate_id = value.to_s
    provider_id_variants.any? do |provider_id|
      candidate_id == provider_id || candidate_id.end_with?(":#{provider_id}")
    end
  end

  def find_conversation(payload, direct_only: false)
    phone = extract_phone(payload, direct_only: direct_only)
    return unless phone.present?

    payload_phones = direct_only ? [phone] : extract_phones(payload)
    contact = Contact.where(account_id: ACCOUNT_ID).where.not(phone_number: nil).find do |candidate|
      payload_phones.include?(normalize_phone(candidate.phone_number))
    end
    return unless contact

    Conversation.where(account_id: ACCOUNT_ID, contact_id: contact.id)
                .order(last_activity_at: :desc).first
  end

  def message_update_attributes(message, payload, raw_status)
    normalized_status = promote_status(message.status, normalize_status(raw_status))
    attributes = message.additional_attributes.is_a?(Hash) ? message.additional_attributes : {}
    provider_id = extract_provider_ids(payload).first
    attributes = attributes.merge(
      'uazapi_status' => raw_status,
      'uazapi_event_at' => Time.current.iso8601
    )
    attributes['uazapi_message_id'] = provider_id if provider_id.present?

    { status: normalized_status, additional_attributes: attributes }
  end

  def promote_status(current_status, incoming_status)
    return incoming_status if incoming_status == :failed
    return incoming_status if current_status.blank? || current_status == 'failed'

    rank = { 'sent' => 0, 'delivered' => 1, 'read' => 2 }
    current_rank = rank.fetch(current_status.to_s, 0)
    incoming_rank = rank.fetch(incoming_status.to_s, 0)

    incoming_rank >= current_rank ? incoming_status : current_status
  end

  def normalize_status(value)
    normalized = value.to_s.downcase
    if normalized.match?(/\A\d+\z/)
      return :sent if %w[0 1 2].include?(normalized)
      return :delivered if normalized == '3'
      return :read if %w[4 5].include?(normalized)
      return :sent
    end

    return :read if normalized.include?('read') || normalized.include?('played') || normalized.include?('seen')
    return :delivered if normalized.include?('deliver') || normalized.include?('delivery')
    return :failed if normalized.include?('fail') || normalized.include?('error') || normalized.include?('cancel')

    :sent
  end

  def extract_status(payload)
    value_for_keys(
      payload,
      %w[status ack messageStatus message_status message_state state ackStatus ack_status acknowledgment acknowledgement statusCode status_code]
    )
  end

  def value_for_keys(payload, keys)
    values_for_keys(payload, keys).first
  end

  def extract_provider_ids(payload)
    explicit_values = values_for_keys(
      payload,
      %w[messageid messageId message_id source_id sourceId sourceID]
    )

    message_id_values = array_values_for_keys(
      payload,
      %w[messageids messageIds message_ids]
    )

    contextual_ids = payload_hashes(payload).filter_map do |node|
      keys = node.keys.map(&:to_s).map(&:downcase)
      next unless keys.intersect?(%w[status state ack fromme wassentbyapi messageid messageids message_ids chatid remotejid participant])

      values = [node['id'], node['ID'], node['Id']]
      values.concat(
        node.filter_map do |key, value|
          next unless %w[messageids messageids message_ids].include?(key.to_s.downcase)

          value
        end.flat_map { |value| value.is_a?(Array) ? value : [value] }
      )
      values.compact
    end

    (explicit_values + message_id_values + contextual_ids.flatten).compact_blank.map(&:to_s).uniq
  end

  def array_values_for_keys(payload, keys)
    normalized_keys = keys.map(&:downcase)

    payload_hashes(payload).flat_map do |node|
      node.filter_map do |key, value|
        next unless normalized_keys.include?(key.to_s.downcase)

        value
      end.flat_map { |value| value.is_a?(Array) ? value : [value] }
    end
  end

  def extract_phone(payload, direct_only: false)
    return normalize_phone(extract_chat_identifier(payload)) if direct_only

    extract_phones(payload).first
  end

  def extract_chat_identifier(payload)
    value_for_keys(
      payload,
      %w[remoteJid remote_jid remoteJidAlt remote_jid_alt chatId chatid chat_id chatJid chat_jid jid participant sender from phone number]
    )
  end

  def extract_phones(payload)
    values = values_for_keys(
      payload,
      %w[chatid chatId chat_id sender from to phone number remoteJid remote_jid participant]
    )

    values.filter_map { |value| normalize_phone(value) }.select { |value| value.length >= 10 }.uniq
  end

  def payload_hashes(payload)
    queue = payload.is_a?(Hash) ? [payload] : Array(payload).select { |value| value.is_a?(Hash) }
    nodes = []

    until queue.empty? || nodes.length >= 100
      node = queue.shift
      nodes << node
      node.each_value do |value|
        if value.is_a?(Hash)
          queue << value
        elsif value.is_a?(Array)
          queue.concat(value.select { |item| item.is_a?(Hash) })
        end
      end
    end

    nodes
  end

  def values_for_keys(payload, keys)
    normalized_keys = keys.map(&:downcase)

    payload_hashes(payload).flat_map do |node|
      node.filter_map do |key, value|
        next unless normalized_keys.include?(key.to_s.downcase)
        next if value.is_a?(Hash) || value.is_a?(Array)

        value
      end
    end
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits = digits.sub(/^55(?=\d{10,11}$)/, '')
    digits.presence
  end
end
