class Webhooks::UazapiController < ActionController::API
  ACCOUNT_ID = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  WEBHOOK_TOKEN = ENV.fetch('ROTTABRASIL_UAZAPI_WEBHOOK_TOKEN', 'rotta-uazapi-ack-v1').freeze

  def process_payload
    return render json: { ok: false }, status: :unauthorized unless params[:token].to_s == WEBHOOK_TOKEN

    payload = JSON.parse(request.raw_post.presence || '{}')
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

  def find_message(payload)
    provider_ids = extract_provider_ids(payload)
    message = Message.where(account_id: ACCOUNT_ID, message_type: Message.message_types[:outgoing])
                     .where(source_id: provider_ids)
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
      (external_ids + [candidate.source_id]).compact.map(&:to_s).intersect?(provider_ids)
    end || candidates.first
  end

  def find_conversation(payload)
    phone = extract_phone(payload)
    return unless phone.present?

    contact = Contact.where(account_id: ACCOUNT_ID).where.not(phone_number: nil).find do |candidate|
      extract_phones(payload).include?(normalize_phone(candidate.phone_number))
    end
    return unless contact

    Conversation.where(account_id: ACCOUNT_ID, contact_id: contact.id)
                .order(last_activity_at: :desc).first
  end

  def message_update_attributes(message, payload, raw_status)
    normalized_status = normalize_status(raw_status)
    attributes = message.additional_attributes.is_a?(Hash) ? message.additional_attributes : {}
    provider_id = extract_provider_ids(payload).first
    attributes = attributes.merge(
      'uazapi_status' => raw_status,
      'uazapi_event_at' => Time.current.iso8601
    )
    attributes['uazapi_message_id'] = provider_id if provider_id.present?

    { status: normalized_status, additional_attributes: attributes }
  end

  def normalize_status(value)
    normalized = value.to_s.downcase
    return :read if normalized.include?('read') || normalized.include?('played') || normalized.include?('seen')
    return :delivered if normalized.include?('deliver') || normalized.include?('delivery')
    return :failed if normalized.include?('fail') || normalized.include?('error') || normalized.include?('cancel')

    :sent
  end

  def extract_status(payload)
    value_for_keys(
      payload,
      %w[status ack messageStatus message_status message_state state]
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

    contextual_ids = payload_hashes(payload).filter_map do |node|
      keys = node.keys.map(&:to_s).map(&:downcase)
      next unless keys.intersect?(%w[status ack fromme wassentbyapi messageid chatid remotejid participant])

      node['id'] || node['ID'] || node['Id']
    end

    (explicit_values + contextual_ids).compact_blank.map(&:to_s).uniq
  end

  def extract_phone(payload)
    extract_phones(payload).first
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
