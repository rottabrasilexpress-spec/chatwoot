class Messages::SendOnApiService < Base::SendOnChannelService
  UAZAPI_PATH = '/send/text'.freeze
  UAZAPI_MEDIA_PATH = '/send/media'.freeze
  MAX_RATE_LIMIT_RETRIES = 3
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

  def self.whatsapp_text(content)
    content.to_s.gsub(/\r\n?/, "\n").gsub(/(\\+)\n/) do
      slashes = Regexp.last_match(1)
      "#{slashes.length.odd? ? slashes[0...-1] : slashes}\n"
    end
  end

  def self.pending_text_echo(conversation, content)
    return if conversation.blank? || content.blank?

    candidates = conversation.messages.where(message_type: :outgoing, private: false, source_id: nil)
                             .where('updated_at >= ?', 5.minutes.ago).order(:updated_at, :id).limit(100)
                             .includes(:attachments).select do |candidate|
      attributes = candidate.content_attributes.to_h
      attributes['rotta_uazapi_pending_echo'] == true &&
        attributes['uazapi_track_id'] == "message-#{candidate.id}" &&
        attributes['rotta_uazapi_retry_at'].blank? && recent_echo_claim?(candidate) && candidate.attachments.empty? &&
        whatsapp_text(candidate.content).strip == whatsapp_text(content).strip
    end
    # Text is only a fallback for an explicitly claimed send. Never guess
    # which of two identical in-flight messages an untracked import belongs to.
    candidates.one? ? candidates.first : nil
  end

  def self.recent_echo_claim?(candidate)
    claimed_at = candidate.content_attributes.to_h['rotta_uazapi_claimed_at']
    (claimed_at.present? ? Time.iso8601(claimed_at) : candidate.created_at) >= 5.minutes.ago
  rescue ArgumentError
    false
  end

  def self.canonical_provider_id(value)
    value.to_s.sub(/\A(?:uazapi:)?\d{10,15}:([a-f0-9]{12,64})\z/i, '\1').presence
  end

  private

  def channel_class
    Channel::Api
  end

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
    body[:track_source] = uazapi_track_source
    body[:track_id] = "message-#{message.id}"

    response = post_to_uazapi(UAZAPI_PATH, body)
    return if response.nil?

    return fail_message(provider_error(response)) unless response.success?

    provider_id = provider_message_id(response)
    persist_provider_id(provider_id) if provider_id.present?
    Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_accepted
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
      track_source: uazapi_track_source,
      track_id: "message-#{message.id}"
    }
    body[:replyid] = content_attributes[:in_reply_to_external_id] if content_attributes[:in_reply_to_external_id].present?

    response = post_to_uazapi(UAZAPI_MEDIA_PATH, body)
    return if response.nil?

    return fail_message(provider_error(response)) unless response.success?

    provider_id = provider_message_id(response)
    persist_provider_id(provider_id) if provider_id.present?
    Rails.logger.info("[ROTTABRASIL_API] voice message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    if @uazapi_request_accepted
      mark_delivery_confirmation_pending(e)
    else
      fail_message("Falha ao enviar áudio pela Uazapi: #{e.message}")
    end
  end

  def uazapi_base_url
    ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').delete_suffix('/')
  end

  def uazapi_track_source
    message.sender_type == 'User' ? 'chatwoot-human' : 'chatwoot'
  end

  def outgoing_text
    # UAZAPI receives WhatsApp's native text syntax. Keep emojis, single
    # asterisks, blank lines and separators intact. The editor serializes
    # Shift+Enter as a markdown hard break (backslash + newline), which the
    # WhatsApp API treats as literal text. Remove only that marker, not paths
    # or escaped pairs of literal backslashes.
    self.class.whatsapp_text(message.outgoing_content)
  end

  def post_to_uazapi(path, body)
    response = HTTParty.post(
      "#{uazapi_base_url}#{path}",
      headers: uazapi_headers,
      body: body.to_json,
      timeout: 30
    )
    @uazapi_request_accepted = response.success?
    if response.code == 429
      schedule_rate_limit_retry(response)
      return nil
    end
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
      body['messageId'], body['messageid'], body['message_id'],
      body.dig('key', 'id'), body.dig('message', 'key', 'id'), body.dig('data', 'key', 'id'),
      body['id'], body.dig('data', 'id'), body.dig('response', 'id')
    ]

    self.class.canonical_provider_id(candidates.find { |value| value.present? })
  end

  def schedule_rate_limit_retry(response)
    retry_at = nil
    exhausted = false
    message.with_lock do
      next if message.source_id.present? || message.status.in?(%w[delivered read])

      attributes = message.content_attributes.to_h.stringify_keys
      count = attributes['rotta_uazapi_retry_count'].to_i
      if count >= MAX_RATE_LIMIT_RETRIES
        exhausted = true
        next
      end

      backoff = Time.current + (60 * (2**count) + message.id % 15).seconds
      header = response.headers['retry-after'].to_s
      provider_retry_at = if header.match?(/\A\d+\z/)
                            Time.current + header.to_i.seconds
                          elsif header.present?
                            begin
                              Time.httpdate(header)
                            rescue ArgumentError
                              nil
                            end
                          end
      retry_at = [backoff, provider_retry_at].compact.max
      attributes.delete('external_error')
      attributes['rotta_uazapi_retry_count'] = count + 1
      attributes['rotta_uazapi_retry_at'] = retry_at.iso8601(6)
      message.update!(status: :sent, content_attributes: attributes)
    end
    return fail_message(provider_error(response)) if exhausted
    return unless retry_at

    SendReplyJob.set(wait_until: retry_at).perform_later(message.id)
    Rails.logger.warn("[ROTTABRASIL_API] message=#{message.id} rate_limited retry_at=#{retry_at.iso8601}")
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
      next if message.failed? && attributes[:rotta_uazapi_retry_count].to_i >= MAX_RATE_LIMIT_RETRIES

      retry_at = attributes[:rotta_uazapi_retry_at]
      retry_due = retry_at.present? && Time.iso8601(retry_at) <= Time.current
      next if retry_at.present? && !retry_due

      pending_for_this_message = attributes[:rotta_uazapi_pending_echo] &&
        attributes[:uazapi_track_id].to_s == "message-#{message.id}" && !retry_due

      unless message.source_id.present? || pending_for_this_message
        mark_pending_uazapi_echo
        claimed = true
      end
    end

    claimed
  end

  def mark_pending_uazapi_echo
    attributes = message.content_attributes.to_h.stringify_keys
    attributes.delete('rotta_uazapi_retry_at')
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

  def persist_provider_id(provider_id)
    message.with_lock do
      attributes = message.content_attributes.to_h.stringify_keys
      attributes.delete('rotta_uazapi_pending_echo')
      attributes.delete('external_error')
      attributes.delete('rotta_uazapi_retry_at')
      attributes.delete('rotta_uazapi_retry_count')
      message.update!(
        source_id: message.source_id.presence || provider_id,
        status: message.failed? ? :sent : message.status,
        content_attributes: attributes
      )
    end
  end

  def fail_message(error)
    message.with_lock do
      # An echo/receipt may arrive before the HTTP request finishes. A late
      # request failure cannot invalidate the provider's confirmed message.
      return if message.source_id.present? || message.status.in?(%w[delivered read])

      attributes = message.content_attributes.to_h.stringify_keys
      attributes.delete('rotta_uazapi_pending_echo')
      attributes.delete('rotta_uazapi_retry_at')
      attributes['external_error'] = error.to_s.truncate(500)
      message.update!(status: :failed, content_attributes: attributes)
    end
    Rails.logger.error("[ROTTABRASIL_API] message=#{message.id} failed #{error}")
  end

  def mark_delivery_confirmation_pending(error)
    message.with_lock do
      status = message.status.in?(%w[delivered read]) ? message.status : :sent
      attributes = message.additional_attributes.to_h
      if message.source_id.present? || %w[delivered read].include?(status.to_s)
        attributes.delete('rotta_uazapi_confirmation_pending')
      else
        attributes['rotta_uazapi_confirmation_pending'] = true
      end

      message.update!(status: status, external_error: nil, additional_attributes: attributes)
    end
    Rails.logger.warn("[ROTTABRASIL_API] message=#{message.id} confirmation_pending error=#{error.class.name}")
  end
end
