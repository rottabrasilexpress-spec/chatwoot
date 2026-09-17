module Messages::UazapiDelivery
  UAZAPI_PATH = '/send/text'.freeze
  UAZAPI_MEDIA_PATH = '/send/media'.freeze
  UAZAPI_AMBIGUOUS_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    SocketError,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::ETIMEDOUT,
    Errno::EPIPE,
    EOFError,
    IOError,
    Timeout::Error
  ].uniq.freeze

  private

  def perform_reply
    unless claim_uazapi_send
      Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} skipped duplicate send claim")
      return
    end

    return perform_media_reply if message.attachments.present?

    content_attributes = message.content_attributes.to_h.with_indifferent_access
    body = {
      number: recipient_number,
      text: outgoing_text,
      delay: 2,
      readchat: true,
      linkPreview: false
    }
    body[:forward] = true if content_attributes[:rotta_forwarded]
    body[:replyid] = content_attributes[:in_reply_to_external_id] if content_attributes[:in_reply_to_external_id].present?
    body[:track_source] = 'chatwoot'
    body[:track_id] = "message-#{message.id}"

    response = post_to_uazapi(UAZAPI_PATH, body)
    return if response.nil?

    return unless handle_uazapi_response(response)

    provider_id = provider_message_id(response)
    persist_provider_id(provider_id) if provider_id.present?
    Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_started
      mark_delivery_confirmation_pending(e)
    else
      fail_message("Falha ao enviar pela Uazapi: #{e.message}")
    end
  end

  def perform_media_reply
    return fail_message('A UAZAPI aceita uma mídia por mensagem neste canal') if message.attachments.size != 1

    attachment = message.attachments.first
    return fail_message('Somente áudio gravado é suportado neste canal') unless attachment.audio?

    file_url = attachment.download_url.to_s
    return fail_message('Áudio sem URL pública para a UAZAPI') unless file_url.match?(%r{\Ahttps?://}i)

    content_attributes = message.content_attributes.to_h.with_indifferent_access
    body = {
      number: recipient_number,
      type: 'ptt',
      file: file_url,
      text: outgoing_text,
      delay: 2,
      readchat: true,
      track_source: 'chatwoot',
      track_id: "message-#{message.id}"
    }
    body[:replyid] = content_attributes[:in_reply_to_external_id] if content_attributes[:in_reply_to_external_id].present?

    response = post_to_uazapi(UAZAPI_MEDIA_PATH, body)
    return if response.nil?

    return unless handle_uazapi_response(response)

    provider_id = provider_message_id(response)
    persist_provider_id(provider_id) if provider_id.present?
    Rails.logger.info("[ROTTABRASIL_API] voice message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_started
      mark_delivery_confirmation_pending(e)
    else
      fail_message("Falha ao enviar áudio pela Uazapi: #{e.message}")
    end
  end

  def uazapi_base_url
    ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').delete_suffix('/')
  end

  def outgoing_text
    message.outgoing_content.to_s
  end

  def post_to_uazapi(path, body)
    request_url = "#{uazapi_base_url}#{path}"
    request_headers = uazapi_headers
    request_body = body.to_json
    @uazapi_request_started = true
    HTTParty.post(
      request_url,
      headers: request_headers,
      body: request_body,
      timeout: 30
    )
  rescue *UAZAPI_AMBIGUOUS_ERRORS => e
    mark_delivery_confirmation_pending(e)
    nil
  end

  def handle_uazapi_response(response)
    return true if response.success?
    return fail_message(provider_error(response)) if confirmed_provider_rejection?(response)

    mark_delivery_confirmation_pending(
      StandardError.new("Uazapi returned an ambiguous HTTP #{response.code} response")
    )
    false
  end

  def confirmed_provider_rejection?(response)
    code = response.code.to_i
    code.between?(400, 499) && ![408, 425, 429].include?(code)
  end

  def uazapi_headers
    token = ENV.fetch('ROTTABRASIL_UAZAPI_TOKEN') { ENV.fetch('ROTTABRASIL_UAZAPI_INSTANCE_TOKEN') }

    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'convert' => 'true',
      'token' => token
    }
  end

  def recipient_number
    source_id = conversation.contact_inbox.source_id.to_s.strip
    return source_id if source_id.end_with?('@g.us', '@newsletter', '@lid', '@s.whatsapp.net')

    digits = source_id.gsub(/\D/, '')
    raise ArgumentError, 'Contato sem número WhatsApp válido' if digits.blank?

    digits
  end

  def provider_message_id(response)
    body = response.parsed_response
    candidates = [
      body['id'], body['messageId'], body['messageid'], body['message_id'],
      body.dig('key', 'id'), body.dig('message', 'key', 'id'), body.dig('data', 'key', 'id'),
      body.dig('data', 'id'), body.dig('response', 'id')
    ]

    candidates.find { |value| value.present? }.to_s.presence
  end

  def provider_error(response)
    body = response.parsed_response
    detail = if body.is_a?(Hash)
               body['error'] || body['message'] || body.dig('response', 'message')
             end

    "Uazapi recusou o envio (HTTP #{response.code})#{detail.present? ? ": #{detail}" : ''}"
  end

  # A message can be enqueued more than once by the after-commit callback,
  # a retry, or a worker redelivery. The provider may accept both requests
  # even when Chatwoot later correlates both echoes to the same message.
  # Claim the message in a short transaction before the network request so
  # only the first worker may send it. The pending marker remains the durable
  # claim until the provider echo or a confirmed failure clears it.
  def claim_uazapi_send
    claimed = false

    with_uazapi_send_lock(message) do
      message.reload
      attributes = message.content_attributes.to_h.with_indifferent_access
      pending_claim = ActiveModel::Type::Boolean.new.cast(attributes[:rotta_uazapi_pending_echo])
      track_id = attributes[:uazapi_track_id].to_s.presence
      canonical_track_id = "message-#{message.id}"

      if track_id.present? && track_id != canonical_track_id
        Rails.logger.error(
          "[ROTTABRASIL_API] message=#{message.id} blocked inconsistent send claim track_id=#{track_id}"
        )
      elsif message.source_id.present? || pending_claim
        Rails.logger.info(
          "[ROTTABRASIL_API] message=#{message.id} skipped existing send claim " \
          "track_id=#{track_id || 'unknown'}"
        )
      else
        mark_pending_uazapi_echo
        claimed = true
      end
    end

    claimed
  end

  def with_uazapi_send_lock(record)
    ApplicationRecord.transaction do
      lock_key = "rotta-uazapi-send:#{record.account_id}:#{record.id}"
      sql = ApplicationRecord.sanitize_sql_array(
        ['SELECT pg_advisory_xact_lock(hashtext(?))', lock_key]
      )
      ApplicationRecord.connection.execute(sql)
      yield
    end
  end

  def mark_pending_uazapi_echo
    attributes = message.content_attributes.to_h.stringify_keys
    message.update!(
      content_attributes: attributes.merge(
        'rotta_uazapi' => true,
        'external_echo' => true,
        'rotta_uazapi_pending_echo' => true,
        'uazapi_track_source' => 'chatwoot',
        'uazapi_track_id' => "message-#{message.id}",
        'rotta_uazapi_claimed_at' => Time.current.iso8601
      )
    )
  end

  def persist_provider_id(provider_id)
    with_uazapi_send_lock(message) do
      message.reload
      attributes = message.content_attributes.to_h.stringify_keys
      attributes.delete('rotta_uazapi_pending_echo')
      if message.source_id.present?
        Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} provider id already correlated; preserving source_id")
        message.update!(content_attributes: attributes)
      else
        message.update!(source_id: provider_id, content_attributes: attributes)
      end
    end
  end

  def fail_message(error)
    with_uazapi_send_lock(message) do
      message.reload
      attributes = message.content_attributes.to_h.stringify_keys
      attributes.delete('rotta_uazapi_pending_echo')
      message.update!(
        status: :failed,
        external_error: error.to_s.truncate(500),
        content_attributes: attributes
      )
    end
    Rails.logger.error("[ROTTABRASIL_API] message=#{message.id} failed #{error}")
  end

  def mark_delivery_confirmation_pending(error)
    with_uazapi_send_lock(message) do
      message.reload
      attributes = message.additional_attributes.to_h
      if message.source_id.present? || message.status.in?(%w[delivered read])
        attributes.delete('rotta_uazapi_confirmation_pending')
      else
        attributes['rotta_uazapi_confirmation_pending'] = true
      end

      status = message.status.in?(%w[delivered read]) ? message.status : :sent
      message.update!(status: status, external_error: nil, additional_attributes: attributes)
    end
    Rails.logger.warn("[ROTTABRASIL_API] message=#{message.id} confirmation_pending error=#{error.class.name}")
  end
end
