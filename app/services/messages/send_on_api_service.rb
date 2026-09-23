class Messages::SendOnApiService < Base::SendOnChannelService
  UAZAPI_PATH = '/send/text'.freeze
  UAZAPI_MEDIA_PATH = '/send/media'.freeze
  HUMAN_LOCK_WEBHOOK_HEADER = 'X-RottaWoot-Human-Token'.freeze
  HUMAN_LOCK_FAILURE_MESSAGE = 'A IA não confirmou a pausa deste atendimento. A mensagem não foi enviada; tente novamente em instantes.'.freeze
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

  def channel_class
    Channel::Api
  end

  def perform_reply
    unless claim_uazapi_send
      Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} skipped duplicate send claim")
      return
    end

    return unless confirm_human_intervention

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
    body[:track_source] = uazapi_track_source
    body[:track_id] = "message-#{message.id}"

    response = post_to_uazapi(UAZAPI_PATH, body)
    return if response.nil?

    return fail_message(provider_error(response)) unless response.success?

    provider_id = provider_message_id(response)
    persist_provider_acceptance(provider_id)
    Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_accepted
      mark_delivery_confirmation_pending(e)
    elsif @human_lock_required && !@human_lock_confirmed
      fail_human_lock_message
    elsif @human_lock_confirmed && !@human_lock_ack_persisted
      fail_human_lock_message
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
      track_source: uazapi_track_source,
      track_id: "message-#{message.id}"
    }
    body[:replyid] = content_attributes[:in_reply_to_external_id] if content_attributes[:in_reply_to_external_id].present?

    response = post_to_uazapi(UAZAPI_MEDIA_PATH, body)
    return if response.nil?

    return fail_message(provider_error(response)) unless response.success?

    provider_id = provider_message_id(response)
    persist_provider_acceptance(provider_id)
    Rails.logger.info("[ROTTABRASIL_API] voice message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_accepted
      mark_delivery_confirmation_pending(e)
    else
      fail_message("Falha ao enviar áudio pela Uazapi: #{e.message}")
    end
  end

  def confirm_human_intervention
    return true unless human_intervention_message?

    @human_lock_required = true
    attributes = message.content_attributes.to_h.with_indifferent_access
    if attributes[:rotta_human_lock_ack_message_id].to_s == message.id.to_s
      @human_lock_confirmed = true
      @human_lock_ack_persisted = true
      return true
    end

    webhook_url = ENV.fetch('ROTTABRASIL_HUMAN_LOCK_WEBHOOK_URL')
    webhook_token = ENV.fetch('ROTTABRASIL_HUMAN_LOCK_WEBHOOK_TOKEN')
    response = HTTParty.post(
      webhook_url,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        HUMAN_LOCK_WEBHOOK_HEADER => webhook_token
      },
      body: human_intervention_payload.to_json,
      timeout: 15
    )

    return fail_human_lock_message(response.code) unless response.success?

    result = response.parsed_response
    unless result.is_a?(Hash) && result['success'] == true && result['event_id'].to_s == message.id.to_s
      return fail_human_lock_message(response.code, 'resposta sem confirmação válida')
    end

    @human_lock_confirmed = true
    persist_human_lock_ack
    @human_lock_ack_persisted = true
    true
  rescue KeyError => e
    Rails.logger.error("[ROTTABRASIL_HUMAN_LOCK] message=#{message.id} configuration_missing=#{e.key}")
    fail_human_lock_message
  rescue StandardError => e
    Rails.logger.error("[ROTTABRASIL_HUMAN_LOCK] message=#{message.id} confirmation_failed=#{e.class.name}")
    fail_human_lock_message
  end

  def human_intervention_message?
    message.sender_type == 'User' && (message.outgoing? || message.template?) && !message.private?
  end

  def human_intervention_payload
    {
      event: 'rottawoot.human_message_created',
      message_id: message.id.to_s,
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      conversation_id: message.conversation_id,
      sender_type: message.sender_type,
      sender_id: message.sender_id,
      message_type: message.message_type,
      private: message.private?,
      instance: 'rotta',
      remote_jid: human_intervention_remote_jid,
      content: outgoing_text,
      content_type: message.content_type,
      track_source: 'chatwoot-human',
      track_id: "message-#{message.id}"
    }
  end

  def human_intervention_remote_jid
    source_id = contact_inbox.source_id.to_s.strip
    return source_id if source_id.end_with?('@s.whatsapp.net', '@g.us')

    phone_digits = contact.phone_number.to_s.gsub(/\D/, '')
    return "#{phone_digits}@s.whatsapp.net" if phone_digits.present?

    raise ArgumentError, 'Contato sem identificador WhatsApp válido para pausar a IA'
  end

  def persist_human_lock_ack
    attributes = message.content_attributes.to_h.stringify_keys
    attributes.delete('rotta_human_lock_confirmation_pending')
    message.update!(
      content_attributes: attributes.merge(
        'rotta_human_lock_ack_message_id' => message.id.to_s,
        'rotta_human_lock_confirmed_at' => Time.current.iso8601
      )
    )
  end

  def fail_human_lock_message(status_code = nil, detail = nil)
    attributes = message.content_attributes.to_h.stringify_keys
    # The human-lock handshake happens before UAZAPI is called. Release only
    # the send claim so Chatwoot can safely retry after the lock service recovers.
    attributes.delete('rotta_uazapi_pending_echo')
    attributes['rotta_human_lock_confirmation_pending'] = true
    message.update!(
      status: :failed,
      external_error: HUMAN_LOCK_FAILURE_MESSAGE,
      content_attributes: attributes
    )
    Rails.logger.error(
      "[ROTTABRASIL_HUMAN_LOCK] message=#{message.id} send_blocked=true " \
      "http_status=#{status_code || 'unavailable'} detail=#{detail || 'confirmation unavailable'}"
    )
    false
  end

  def uazapi_base_url
    ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').delete_suffix('/')
  end

  def uazapi_track_source
    message.sender_type == 'User' ? 'chatwoot-human' : 'chatwoot'
  end

  def outgoing_text
    # UAZAPI receives WhatsApp's native text syntax. Keep emojis, single
    # asterisks, blank lines and separators intact; only normalize platform
    # line endings so Windows input does not introduce stray carriage returns.
    message.outgoing_content.to_s.gsub(/\r\n?/, "\n")
  end

  def post_to_uazapi(path, body)
    response = HTTParty.post(
      "#{uazapi_base_url}#{path}",
      headers: uazapi_headers,
      body: body.to_json,
      timeout: 30
    )
    @uazapi_request_accepted = response.success?
    response
  rescue *UAZAPI_AMBIGUOUS_ERRORS => e
    mark_delivery_confirmation_pending(e)
    nil
  end

  def uazapi_headers
    token = ENV.fetch('ROTTABRASIL_UAZAPI_TOKEN') { ENV.fetch('ROTTABRASIL_UAZAPI_INSTANCE_TOKEN') }

    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'token' => token
    }
  end

  def recipient_number
    source_id = conversation.contact_inbox.source_id.to_s.strip
    return source_id if source_id.end_with?('@g.us', '@newsletter', '@s.whatsapp.net')

    # Modern WhatsApp inbound events may identify a person with an opaque LID.
    # The send endpoint expects the actual telephone number for one-to-one chats.
    if source_id.end_with?('@lid')
      phone_digits = conversation.contact.phone_number.to_s.gsub(/\D/, '')
      return phone_digits if phone_digits.present?

      raise ArgumentError, 'Contato identificado por LID, mas sem telefone válido para resposta'
    end

    # Chatwoot intentionally generates an opaque UUID for ContactInbox records
    # backed by Channel::Api. It is an internal conversation key, not the
    # WhatsApp recipient. For direct Uazapi chats, the contact phone is the
    # authoritative destination; using the UUID makes the provider reject or
    # misroute the message.
    phone_digits = conversation.contact.phone_number.to_s.gsub(/\D/, '')
    return phone_digits if phone_digits.present?

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

    ApplicationRecord.transaction do
      lock_key = "rotta-uazapi-send:#{message.account_id}:#{message.id}"
      sql = ApplicationRecord.sanitize_sql_array(
        ['SELECT pg_advisory_xact_lock(hashtext(?))', lock_key]
      )
      ApplicationRecord.connection.execute(sql)

      message.reload
      attributes = message.content_attributes.to_h.with_indifferent_access
      pending_for_this_message = attributes[:rotta_uazapi_pending_echo] &&
        attributes[:uazapi_track_id].to_s == "message-#{message.id}"

      unless message.source_id.present? || pending_for_this_message
        mark_pending_uazapi_echo
        claimed = true
      end
    end

    claimed
  end

  def mark_pending_uazapi_echo
    attributes = message.content_attributes.to_h.stringify_keys
    message.update!(
      content_attributes: attributes.merge(
        'rotta_uazapi' => true,
        'external_echo' => true,
        'rotta_uazapi_pending_echo' => true,
        'uazapi_track_source' => uazapi_track_source,
        'uazapi_track_id' => "message-#{message.id}",
        'rotta_uazapi_claimed_at' => Time.current.iso8601
      )
    )
  end

  def persist_provider_acceptance(provider_id)
    message.with_lock do
      attributes = message.content_attributes.to_h.stringify_keys
      attributes.delete('rotta_human_lock_confirmation_pending')
      attributes.delete('rotta_uazapi_pending_echo') if provider_id.present?
      status = message.status.in?(%w[delivered read]) ? message.status : :sent
      updates = { status: status, external_error: nil, content_attributes: attributes }
      updates[:source_id] = provider_id if provider_id.present?
      message.update!(updates)
    end
  end

  def fail_message(error)
    attributes = message.content_attributes.to_h.stringify_keys
    attributes.delete('rotta_uazapi_pending_echo')
    message.update!(
      status: :failed,
      external_error: error.to_s.truncate(500),
      content_attributes: attributes
    )
    Rails.logger.error("[ROTTABRASIL_API] message=#{message.id} failed #{error}")
  end

  def mark_delivery_confirmation_pending(error)
    status = message.status.in?(%w[delivered read]) ? message.status : :sent
    attributes = message.additional_attributes.to_h
    if %w[delivered read].include?(status.to_s)
      attributes.delete('rotta_uazapi_confirmation_pending')
    else
      attributes['rotta_uazapi_confirmation_pending'] = true
    end

    message.update!(status: status, external_error: nil, additional_attributes: attributes)
    Rails.logger.warn("[ROTTABRASIL_API] message=#{message.id} confirmation_pending error=#{error.class.name}")
  end
end
