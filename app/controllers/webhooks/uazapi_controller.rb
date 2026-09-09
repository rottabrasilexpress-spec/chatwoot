require 'digest'

class Webhooks::UazapiController < ActionController::API
  include Events::Types

  skip_before_action :authenticate_secure_password!, raise: false

  ACCOUNT_ID = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  WEBHOOK_TOKEN = ENV.fetch('ROTTABRASIL_UAZAPI_WEBHOOK_TOKEN').freeze
  UNKNOWN_DELIVERY_EVENT = 'unknown'.freeze

  def process_payload
    route_token = request.path_parameters[:token]
    return render json: { ok: false }, status: :unauthorized unless route_token.to_s == WEBHOOK_TOKEN

    begin_uazapi_delivery
    payload = JSON.parse(request.raw_post.presence || '{}')
    register_uazapi_delivery(payload)
    event = extract_event(payload)

    if presence_event?(event)
      return process_presence_event(payload)
    end

    if contacts_event?(event)
      return process_contacts_event(payload)
    end

    if call_event?(event)
      return process_call_event(payload)
    end

    if incoming_message_event?(event)
      return process_incoming_message(payload)
    end

    raw_status = extract_status(payload)
    return render json: { ok: true, ignored: 'status ausente' } unless raw_status.present?

    messages = find_messages(payload)
    return render json: { ok: true, ignored: 'mensagem não localizada' } if messages.empty?

    messages.each do |message|
      message.update!(message_update_attributes(message, payload, raw_status))
    end

    associate_uazapi_delivery(messages.first.conversation)

    render json: { ok: true, message_ids: messages.map(&:id), status: messages.map(&:status).uniq.join(',') }
  rescue JSON::ParserError => e
    @uazapi_delivery_error = e
    render json: { ok: false, error: 'Payload inválido.' }, status: :bad_request
  rescue ActionDispatch::Http::Parameters::ParseError => e
    @uazapi_delivery_error = e
    render json: { ok: false, error: 'Payload inválido.' }, status: :bad_request
  rescue StandardError => e
    @uazapi_delivery_error = e
    Rails.logger.error("[UazapiWebhook] correlation_id=#{@uazapi_delivery_correlation_id} class=#{e.class.name} error=processing_failed")
    render json: { ok: false, error: 'Falha ao processar confirmação Uazapi.' }, status: :unprocessable_entity
  ensure
    finalize_uazapi_delivery
  end

  private

  def begin_uazapi_delivery
    @uazapi_delivery_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    payload_digest = Digest::SHA256.hexdigest(request.raw_post.to_s)
    @uazapi_delivery_correlation_id = sanitized_correlation_id(request.request_id, payload_digest)
    @uazapi_delivery = UazapiWebhookDelivery.create!(
      account_id: ACCOUNT_ID,
      event: UNKNOWN_DELIVERY_EVENT,
      status: 'received',
      attempts: 1,
      received_at: Time.current,
      payload_digest: payload_digest,
      correlation_id: @uazapi_delivery_correlation_id,
      metadata: request_delivery_metadata
    )
  rescue StandardError => e
    @uazapi_delivery = nil
    Rails.logger.error("[UazapiWebhookTelemetry] start_failed class=#{e.class.name}")
  end

  def register_uazapi_delivery(payload)
    return unless @uazapi_delivery

    @uazapi_delivery.update_columns(
      event: sanitized_delivery_event(extract_event(payload)),
      provider_message_id: extract_provider_ids(payload).first&.to_s&.presence,
      track_id: value_for_keys(payload, %w[track_id trackId])&.to_s&.presence,
      status: 'processing',
      metadata: payload_delivery_metadata(payload),
      updated_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("[UazapiWebhookTelemetry] register_failed correlation_id=#{@uazapi_delivery_correlation_id} class=#{e.class.name}")
  end

  def finalize_uazapi_delivery
    return unless @uazapi_delivery

    response_status = response.status.to_i
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @uazapi_delivery_started_at) * 1000).round
    body = parsed_response_body
    status = delivery_status(response_status, body)
    attributes = {
      status: status,
      processed_at: Time.current,
      duration_ms: duration_ms,
      response_status: response_status,
      updated_at: Time.current
    }
    if @uazapi_delivery_error
      attributes[:error_class] = @uazapi_delivery_error.class.name
      attributes[:error_message] = delivery_error_message(@uazapi_delivery_error)
    elsif response_status >= 400
      attributes[:error_class] = "HTTP::#{response_status}"
      attributes[:error_message] = 'http_error'
    end

    @uazapi_delivery.update_columns(attributes)
    Rails.logger.info(
      "[UazapiWebhookDelivery] delivery_id=#{@uazapi_delivery.id} " \
      "correlation_id=#{@uazapi_delivery_correlation_id} event=#{sanitized_delivery_event(@uazapi_delivery.event)} " \
      "status=#{status} response_status=#{response_status} duration_ms=#{duration_ms}"
    )
  rescue StandardError => e
    Rails.logger.error("[UazapiWebhookTelemetry] finalize_failed correlation_id=#{@uazapi_delivery_correlation_id} class=#{e.class.name}")
  end

  def delivery_status(response_status, body)
    return 'failed' if response_status >= 400

    ignored = body.is_a?(Hash) ? body['ignored'].to_s : ''
    return 'duplicate' if ignored.match?(/duplicad/i)
    return 'ignored' if ignored.present?

    'persisted'
  end

  def parsed_response_body
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    {}
  end

  def delivery_error_message(error)
    error.is_a?(JSON::ParserError) ? 'invalid_json' : 'processing_failed'
  end

  def associate_uazapi_delivery(conversation)
    return unless @uazapi_delivery && conversation

    @uazapi_delivery.update_columns(conversation_id: conversation.id, updated_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[UazapiWebhookTelemetry] association_failed correlation_id=#{@uazapi_delivery_correlation_id} class=#{e.class.name}")
  end

  def request_delivery_metadata
    {
      'content_type' => request.content_type.to_s.presence,
      'content_length' => request.content_length.to_i
    }.compact
  end

  def payload_delivery_metadata(payload)
    keys = payload_hashes(payload).flat_map { |node| node.keys.map { |key| sanitized_metadata_key(key) } }.compact.uniq.sort

    {
      'top_level_keys' => (payload.is_a?(Hash) ? payload.keys.map { |key| sanitized_metadata_key(key) }.compact : []),
      'nested_keys' => keys.first(100),
      'has_message_id' => keys.any? { |key| %w[messageid message_id messageids message_ids].include?(key) },
      'has_chat_identifier' => keys.any? { |key| %w[chatid chat_id remotejid remote_jid jid].include?(key) },
      'has_text_content' => keys.any? { |key| %w[text caption body content].include?(key) }
    }
  end

  def sanitized_metadata_key(key)
    key.to_s.downcase.gsub(/[^a-z0-9_:-]/, '_')[0, 80].presence
  end

  def sanitized_delivery_event(event)
    event.to_s.downcase.gsub(/[^a-z0-9_.:-]/, '_')[0, 100].presence || UNKNOWN_DELIVERY_EVENT
  end

  def sanitized_correlation_id(request_id, payload_digest)
    request_id.to_s.gsub(/[^a-zA-Z0-9_.:-]/, '_')[0, 100].presence || "uazapi-#{payload_digest.first(24)}"
  end

  def process_presence_event(payload)
    presence = normalize_presence(extract_presence(payload))
    return render json: { ok: true, ignored: 'presença ausente' } unless presence

    conversation = find_conversation(payload, direct_only: true)
    return render json: { ok: true, ignored: 'conversa não localizada' } unless conversation
    associate_uazapi_delivery(conversation)

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
    route_event = params[:event].to_s.split('/').first
    known_events = %w[
      connection history message messages messages_update newsletter_messages call calls
      contacts contact presence groups labels chats chat_labels blocks sender
    ]
    return route_event.downcase if known_events.include?(route_event.downcase)

    value_for_keys(payload, %w[event EventType eventType event_name type name]).to_s.downcase
  end

  def presence_event?(event)
    event.include?('presence')
  end

  def contacts_event?(event)
    event.match?(/\Acontacts?(?:[._-].*)?\z/)
  end

  def call_event?(event)
    %w[call calls].include?(event)
  end

  def process_call_event(payload)
    result = RottaUazapiCallEventService.perform(account_id: ACCOUNT_ID, payload: payload)
    conversation_id = Call.where(id: result[:call_ids]).pick(:conversation_id) if result[:call_ids].present?
    associate_uazapi_delivery(Conversation.find_by(id: conversation_id)) if conversation_id
    render json: result
  end

  def incoming_message_event?(event)
    %w[message messages history].include?(event)
  end

  def process_incoming_message(payload)
    incoming = extract_message_payload(payload)
    return render json: { ok: true, ignored: 'mensagem ausente' } unless incoming

    return process_outgoing_echo(payload, incoming) if from_me?(incoming)

    provider_id = message_provider_id(incoming)
    conversation = find_conversation(incoming)
    return render json: { ok: true, ignored: 'conversa não localizada' } unless conversation
    associate_uazapi_delivery(conversation)

    content = incoming_message_content(incoming)
    return render json: { ok: true, ignored: 'conteúdo não suportado' } if content.blank?

    attributes = {
      'rotta_uazapi' => true,
      'uazapi_message_type' => value_for_keys(incoming, %w[type messageType])
    }.compact
    quoted_id = value_for_keys(incoming, %w[quoted quotedId quoted_id replyid reply_id])
    attributes['in_reply_to_external_id'] = quoted_id if quoted_id.present?

    message = with_uazapi_provider_lock(provider_id) do
      if provider_id.present? && Message.where(account_id: ACCOUNT_ID, source_id: provider_id).exists?
        :duplicate
      else
        Messages::MessageBuilder.new(
          nil,
          conversation,
          ActionController::Parameters.new(
            content: content,
            message_type: 'incoming',
            private: false,
            source_id: provider_id,
            content_attributes: attributes
          )
        ).perform
      end
    end

    return render json: { ok: true, ignored: 'mensagem duplicada', source_id: provider_id } if message == :duplicate

    if incoming_media?(incoming, provider_id)
      RottaUazapiMessageMediaSyncJob.perform_later(
        conversation.account_id,
        message.id,
        provider_id,
        incoming_media_url(incoming),
        incoming_media_type(incoming)
      )
    end

    RottaUazapiContactAvatarSyncJob.perform_later(conversation.account_id, conversation.contact_id)
    render json: { ok: true, message_ids: [message.id], source_id: provider_id }
  end

  def process_outgoing_echo(payload, incoming)
    provider_id = message_provider_id(incoming)
    return render json: { ok: true, ignored: 'id da mensagem ausente' } if provider_id.blank?

    existing_message = find_existing_echo_message(payload, provider_id)
    if existing_message
      associate_uazapi_delivery(existing_message.conversation)
      existing_message.update!(source_id: provider_id) if existing_message.source_id.blank?
      return render json: { ok: true, message_ids: [existing_message.id], source_id: provider_id }
    end

    conversation = find_conversation(incoming)
    return render json: { ok: true, ignored: 'conversa não localizada' } unless conversation
    associate_uazapi_delivery(conversation)

    content = incoming_message_content(incoming)
    return render json: { ok: true, ignored: 'conteúdo não suportado' } if content.blank?

    message = conversation.with_lock do
      # The webhook and SendReplyJob can finish at the same time. Recheck while
      # holding the conversation lock so a retry cannot create a second bubble.
      existing = find_existing_echo_message(payload, provider_id)
      next existing if existing

      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        status: :delivered,
        private: false,
        sender: nil,
        source_id: provider_id,
        content: content,
        content_attributes: outgoing_echo_attributes(payload, incoming)
      )
    end

    render json: { ok: true, message_ids: [message.id], source_id: provider_id }
  end

  def with_uazapi_provider_lock(provider_id)
    return yield if provider_id.blank?

    lock_key = "rotta-uazapi-incoming:#{ACCOUNT_ID}:#{provider_id}"
    ApplicationRecord.transaction do
      sql = ApplicationRecord.sanitize_sql_array(
        ['SELECT pg_advisory_xact_lock(hashtext(?))', lock_key]
      )
      ApplicationRecord.connection.execute(sql)
      yield
    end
  end

  def find_existing_echo_message(payload, provider_id)
    source_ids = [provider_id, "uazapi:#{provider_id}"].uniq
    existing = Message.where(account_id: ACCOUNT_ID, message_type: %i[outgoing template], source_id: source_ids)
                      .order(created_at: :desc).first
    return existing if existing

    track_id = value_for_keys(payload, %w[track_id trackId])&.to_s
    return unless track_id&.match?(/\Amessage-\d+\z/)

    Message.where(account_id: ACCOUNT_ID, message_type: %i[outgoing template], id: track_id.delete_prefix('message-')).first
  end

  def outgoing_echo_attributes(payload, incoming)
    attributes = {
      'rotta_uazapi' => true,
      'external_echo' => true,
      'uazapi_from_me' => true,
      'uazapi_message_type' => value_for_keys(incoming, %w[type messageType]),
      'uazapi_was_sent_by_api' => value_for_keys(incoming, %w[wasSentByApi was_sent_by_api]),
      'uazapi_track_source' => value_for_keys(payload, %w[track_source trackSource]),
      'uazapi_track_id' => value_for_keys(payload, %w[track_id trackId])
    }.compact

    quoted_id = value_for_keys(incoming, %w[quoted quotedId quoted_id replyid reply_id])
    attributes['in_reply_to_external_id'] = quoted_id if quoted_id.present?
    attributes
  end

  def process_contacts_event(payload)
    contacts = find_contacts(payload)
    return render json: { ok: true, event: 'contacts', ignored: 'contato não localizado' } if contacts.empty?

    contacts.each do |contact|
      RottaUazapiContactAvatarSyncJob.perform_later(contact.account_id, contact.id)
    end

    render json: { ok: true, event: 'contacts', contact_ids: contacts.map(&:id), queued: contacts.length }
  end

  def extract_message_payload(payload)
    candidates = payload_hashes(payload).select do |node|
      keys = node.keys.map(&:to_s).map(&:downcase)
      keys.intersect?(%w[messageid message_id id chatid chat_id from_me fromme messagetype type text caption body fileurl file_url mediaurl media_url])
    end

    candidates.max_by do |node|
      keys = node.keys.map(&:to_s).map(&:downcase)
      score = 0
      score += 4 if keys.intersect?(%w[messageid message_id])
      score += 2 if keys.intersect?(%w[chatid chat_id])
      score += 1 if keys.intersect?(%w[from_me fromme type text caption body])
      score += 1 if keys.intersect?(%w[fileurl file_url mediaurl media_url])
      score
    end
  end

  def from_me?(message)
    value = value_for_keys(message, %w[from_me fromMe fromme wasSentByApi]).to_s.downcase
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def message_provider_id(message)
    value_for_keys(message, %w[message_id messageId messageid id])&.to_s&.presence
  end

  def incoming_message_content(message)
    text = value_for_keys(message, %w[text caption body content button_or_listid buttonOrListId selected_id selectedId])
    return text.to_s.strip if text.present?

    type = value_for_keys(message, %w[type messageType]).to_s.strip
    return "[#{type}]" if type.present?

    incoming_media_url(message).present? ? '[arquivo]' : nil
  end

  def with_uazapi_provider_lock(provider_id)
    return yield if provider_id.blank?

    lock_key = "rotta-uazapi-incoming:#{ACCOUNT_ID}:#{provider_id}"
    ApplicationRecord.transaction do
      sql = ApplicationRecord.sanitize_sql_array(
        ['SELECT pg_advisory_xact_lock(hashtext(?))', lock_key]
      )
      ApplicationRecord.connection.execute(sql)
      yield
    end
  end

  def incoming_media?(message, provider_id)
    return false if provider_id.blank? && incoming_media_url(message).blank?

    media_type = incoming_media_type(message).to_s.downcase
    incoming_media_url(message).present? || media_type.match?(/image|video|audio|document|sticker|file/)
  end

  def incoming_media_url(message)
    value_for_keys(message, %w[fileURL fileUrl file_url mediaURL mediaUrl media_url])&.to_s&.strip.presence
  end

  def incoming_media_type(message)
    value_for_keys(message, %w[type messageType])&.to_s&.strip.presence
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

  def find_messages(payload)
    provider_ids = extract_provider_ids(payload)
    provider_id_variants = provider_ids.flat_map { |id| [id, "uazapi:#{id}"] }.uniq
    messages = if provider_ids.present?
                 Message.where(account_id: ACCOUNT_ID, message_type: Message.message_types[:outgoing])
                        .where(source_id: provider_id_variants)
                        .order(created_at: :desc).to_a
               else
                 []
               end
    return messages if messages.present?

    conversation = find_conversation(payload)
    return [] unless conversation

    candidates = conversation.messages
                            .where(message_type: Message.message_types[:outgoing], private: false)
                            .order(created_at: :desc).limit(100)
    return [candidates.first].compact unless provider_ids.present?

    candidates.select do |candidate|
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
    phone_variants = payload_phones.flat_map { |value| contact_phone_variants(value) }.uniq
    contact = Contact.where(account_id: ACCOUNT_ID).where(phone_number: phone_variants).first
    return unless contact

    Conversation.where(account_id: ACCOUNT_ID, contact_id: contact.id)
                .order(last_activity_at: :desc).first
  end

  def find_contacts(payload)
    phone_digits = extract_contact_phone_digits(payload)
    return [] if phone_digits.empty?

    phone_variants = phone_digits.flat_map { |digits| contact_phone_variants(digits) }.uniq
    Contact.where(account_id: ACCOUNT_ID, phone_number: phone_variants).to_a.uniq(&:id)
  end

  def extract_contact_phone_digits(payload)
    values_for_keys(
      payload,
      %w[
        id jid wa_id waId phone number remoteJid remote_jid
        chatid chatId chat_id chatJid chat_jid participant sender from to
      ]
    ).filter_map do |value|
      raw_value = value.to_s
      next if raw_value.downcase.include?('@g.us')

      digits = raw_value.gsub(/\D/, '')
      next if digits.length < 10

      digits
    end.uniq
  end

  def contact_phone_variants(digits)
    normalized = normalize_phone(digits)
    [digits, normalized, "55#{normalized}"].compact_blank.flat_map { |value| [value, "+#{value}"] }.uniq
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
