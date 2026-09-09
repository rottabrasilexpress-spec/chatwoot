class RottaUazapiCallEventService
  PROVIDER = :whatsapp
  TERMINAL_STATUSES = %w[completed no_answer failed rejected].freeze
  STATUS_RANK = { 'ringing' => 0, 'in_progress' => 1, 'completed' => 2, 'no_answer' => 2,
                  'failed' => 2, 'rejected' => 2 }.freeze

  def self.perform(account_id:, payload:)
    new(account_id: account_id, payload: payload).perform
  end

  def initialize(account_id:, payload:)
    @account = Account.find(account_id)
    @payload = payload
  end

  def perform
    events = extract_call_events.uniq { |event| provider_call_id(event) }.filter_map do |event|
      process_event(event)
    end

    {
      ok: true,
      event: 'call',
      call_ids: events.map(&:id),
      provider_call_ids: events.map(&:provider_call_id),
      status: events.map(&:status).uniq.join(',')
    }
  end

  private

  attr_reader :account, :payload

  def process_event(event)
    call_id = provider_call_id(event)
    return if call_id.blank?

    context = call_context(event)
    return unless context

    call = account.calls.whatsapp.find_by(provider_call_id: call_id)
    return update_call(call, event) if call

    create_call(context, event, call_id)
  end

  def create_call(context, event, call_id)
    direction = call_direction(event)
    duration = call_duration(event)
    status = normalize_status(raw_status(event), duration: duration)
    event_time = call_time(event)

    ActiveRecord::Base.transaction do
      attributes = {
        provider: PROVIDER,
        inbox: context[:inbox],
        conversation: context[:conversation],
        contact: context[:contact],
        provider_call_id: call_id,
        direction: direction,
        status: status,
        duration_seconds: duration,
        meta: call_meta(event, event_time)
      }
      attributes[:started_at] = event_time if status == 'in_progress' && event_time
      attributes[:end_reason] = raw_status(event) if terminal_status?(status)
      call = account.calls.create!(attributes)
      message = Voice::CallMessageBuilder.new(call).perform!
      call.update!(message_id: message.id)
      update_conversation(call)
      call
    end
  rescue ActiveRecord::RecordNotUnique
    account.calls.whatsapp.find_by(provider_call_id: call_id)
  end

  def update_call(call, event)
    direction = call_direction(event)
    duration = call_duration(event)
    incoming_status = normalize_status(raw_status(event), duration: duration, call: call)
    next_status = promote_status(call.status, incoming_status)
    event_time = call_time(event)
    attributes = {}

    attributes[:status] = next_status if next_status != call.status
    attributes[:duration_seconds] = duration if duration.present? && call.duration_seconds != duration
    attributes[:started_at] = event_time if next_status == 'in_progress' && call.started_at.blank? && event_time
    attributes[:end_reason] = raw_status(event) if terminal_status?(next_status) && call.end_reason.blank?
    if terminal_status?(next_status)
      updated_meta = call_meta(event, event_time, base: call.meta)
      attributes[:meta] = updated_meta if updated_meta != call.meta
    end

    changed = attributes.present?
    call.update!(attributes) if changed

    if call.message.blank?
      message = Voice::CallMessageBuilder.new(call).perform!
      call.update!(message_id: message.id)
      changed = true
    end
    Voice::CallMessageBuilder.new(call).update_status!(status: call.status, duration_seconds: call.duration_seconds) if changed
    update_conversation(call) if changed
    call
  end

  def call_context(event)
    phone_variants = call_phone_values(event).flat_map { |value| contact_phone_variants(value) }.uniq
    return if phone_variants.empty?

    contact = Contact.where(account_id: account.id, phone_number: phone_variants).first
    return unless contact

    conversation = Conversation.joins(:inbox)
                               .where(account_id: account.id, contact_id: contact.id,
                                      inboxes: { channel_type: 'Channel::Api' })
                               .order(last_activity_at: :desc).first
    inbox = conversation&.inbox || contact.inboxes.where(channel_type: 'Channel::Api').order(:id).first
    inbox ||= account.inboxes.where(channel_type: 'Channel::Api').order(:id).first
    return unless inbox

    unless conversation
      contact_inbox = ContactInbox.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id) do |record|
        record.source_id = call_phone_values(event).first.presence || contact.phone_number
      end
      conversation = account.conversations.create!(
        contact_inbox: contact_inbox,
        inbox: inbox,
        contact: contact,
        status: :open
      )
    end

    { contact: contact, conversation: conversation, inbox: inbox }
  end

  def update_conversation(call)
    call.conversation.update!(
      additional_attributes: (call.conversation.additional_attributes || {}).merge(
        'call_status' => call.display_status,
        'call_direction' => call.direction_label
      )
    )
  end

  def extract_call_events
    explicit = payload_hashes(payload).flat_map do |node|
      node.filter_map do |key, value|
        next unless %w[calls call].include?(key.to_s.downcase)

        value
      end.flat_map { |value| value.is_a?(Array) ? value : [value] }
    end.select { |value| value.is_a?(Hash) }
    return explicit if explicit.present?

    payload_hashes(payload).select do |node|
      keys = node.keys.map { |key| key.to_s.downcase }
      keys.intersect?(%w[callid call_id callid id]) && keys.intersect?(%w[from to chatid chat_id status state direction event])
    end
  end

  def provider_call_id(event)
    value_for_keys(event, %w[id callId callid call_id provider_call_id providerCallId])&.to_s&.presence
  end

  def call_phone_values(event)
    values_for_keys(
      event,
      %w[chatid chatId chat_id remoteJid remote_jid sender from to phone number participant]
    ).filter_map do |value|
      raw = value.to_s
      next if raw.downcase.include?('@g.us')

      digits = raw.gsub(/\D/, '')
      digits.length >= 10 ? digits : nil
    end.uniq
  end

  def call_direction(event)
    direction = value_for_keys(event, %w[direction call_direction callDirection]).to_s.downcase
    return :outgoing if direction.match?(/out|sent|egress/)
    return :incoming if direction.match?(/in|received|ingress/)

    from_me = value_for_keys(event, %w[fromMe from_me fromme wasSentByApi])
    ActiveModel::Type::Boolean.new.cast(from_me) ? :outgoing : :incoming
  end

  def raw_status(event)
    value_for_keys(event, %w[status call_status callStatus state event action notification]).to_s.strip
  end

  def call_duration(event)
    value = value_for_keys(event, %w[duration duration_seconds durationSeconds call_duration seconds])
    return if value.blank?

    value.to_i
  end

  def normalize_status(value, duration:, call: nil)
    normalized = value.to_s.downcase.tr('_', '-')
    return 'no_answer' if normalized.match?(/miss|no-answer|unanswered|timeout|not-answered/)
    return 'in_progress' if normalized.match?(/answer|accept|connect|in-progress|ongoing|talk/)
    return 'rejected' if normalized.match?(/reject|declin|busy|cancel/)
    return 'failed' if normalized.match?(/fail|error/)
    return 'completed' if normalized.match?(/complete|ended|finish|hangup|terminate|closed/) &&
                          (duration.to_i.positive? || call&.in_progress?)
    return 'no_answer' if normalized.match?(/complete|ended|finish|hangup|terminate|closed/)
    return 'ringing' if normalized.match?(/ring|offer|initi|receiv|incoming|start/) || normalized.blank?

    'ringing'
  end

  def promote_status(current, incoming)
    return incoming if current.blank?
    return current if terminal_status?(current) && terminal_status?(incoming)
    return incoming if terminal_status?(incoming)

    STATUS_RANK.fetch(incoming, 0) >= STATUS_RANK.fetch(current.to_s, 0) ? incoming : current
  end

  def terminal_status?(status)
    TERMINAL_STATUSES.include?(status.to_s)
  end

  def call_time(event)
    value = value_for_keys(event, %w[timestamp created createdAt created_at time])
    return if value.blank?

    seconds = value.to_f
    seconds /= 1000 if seconds > 10_000_000_000
    Time.zone.at(seconds)
  rescue ArgumentError, TypeError
    nil
  end

  def call_meta(event, event_time, base: {})
    video = value_for_keys(event, %w[isVideo is_video video])
    (base.is_a?(Hash) ? base : {}).merge(
      'uazapi_status' => raw_status(event).presence,
      'uazapi_event_at' => event_time&.iso8601,
      'uazapi_from' => value_for_keys(event, %w[from sender]).to_s.presence,
      'uazapi_to' => value_for_keys(event, %w[to]).to_s.presence,
      'uazapi_video' => video
    ).compact
  end

  def contact_phone_variants(value)
    digits = value.to_s.gsub(/\D/, '')
    normalized = digits.sub(/^55(?=\d{10,11}$)/, '')
    [digits, normalized, "55#{normalized}"].compact_blank.flat_map { |item| [item, "+#{item}"] }.uniq
  end

  def payload_hashes(value)
    queue = value.is_a?(Hash) ? [value] : Array(value).select { |item| item.is_a?(Hash) }
    nodes = []

    until queue.empty? || nodes.length >= 100
      node = queue.shift
      nodes << node
      node.each_value do |child|
        queue << child if child.is_a?(Hash)
        queue.concat(child.select { |item| item.is_a?(Hash) }) if child.is_a?(Array)
      end
    end
    nodes
  end

  def value_for_keys(hash, keys)
    values_for_keys(hash, keys).first
  end

  def values_for_keys(hash, keys)
    normalized_keys = keys.map(&:downcase)
    hash.filter_map do |key, value|
      next unless normalized_keys.include?(key.to_s.downcase)
      next if value.is_a?(Hash) || value.is_a?(Array)

      value
    end
  end
end
