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
      normalize_phone(candidate.phone_number) == phone
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
    data = payload['data'].is_a?(Hash) ? payload['data'] : payload
    data['status'] || data['ack'] || data['messageStatus'] || data['message_status'] ||
      data.dig('message', 'status') || data.dig('message', 'ack')
  end

  def extract_provider_ids(payload)
    data = payload['data'].is_a?(Hash) ? payload['data'] : payload
    message = data['message'].is_a?(Hash) ? data['message'] : data
    values = [
      data['id'], data['messageid'], data['messageId'], data['source_id'], data['sourceId'],
      message['id'], message['messageid'], message['messageId'],
      message.dig('key', 'id'), message.dig('key', 'messageId')
    ]
    values.compact_blank.map(&:to_s).uniq
  end

  def extract_phone(payload)
    data = payload['data'].is_a?(Hash) ? payload['data'] : payload
    message = data['message'].is_a?(Hash) ? data['message'] : data
    values = [
      data['chatid'], data['chatId'], data['sender'], data['from'], data['to'],
      message['chatid'], message['chatId'], message['sender'], message['from'],
      message.dig('key', 'remoteJid'), message.dig('key', 'participant')
    ]
    values.filter_map { |value| normalize_phone(value) }.find { |value| value.length >= 10 }
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits = digits.sub(/^55(?=\d{10,11}$)/, '')
    digits.presence
  end
end
