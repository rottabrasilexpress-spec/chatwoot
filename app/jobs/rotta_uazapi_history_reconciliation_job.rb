# frozen_string_literal: true

require 'net/http'
require 'uri'

# Recovers WhatsApp messages whose webhook could not reach Chatwoot during an
# outage, including customer messages and outgoing human/AI replies. Every
# recovered message is replayed through the existing
# Uazapi webhook endpoint, which remains the single persistence/deduplication
# path for live and historical traffic.
class RottaUazapiHistoryReconciliationJob < ApplicationJob
  queue_as :uazapi_sync

  BASE_URL = ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').freeze
  ACCOUNT_ID = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  CHATWOOT_INTERNAL_URL = ENV.fetch('ROTTABRASIL_CHATWOOT_INTERNAL_URL', 'http://rails:3000').freeze
  LOOKBACK = ENV.fetch('ROTTABRASIL_UAZAPI_RECONCILIATION_HOURS', '72').to_i.clamp(1, 720).hours
  CHAT_PAGE_SIZE = ENV.fetch('ROTTABRASIL_UAZAPI_RECONCILIATION_CHAT_PAGE_SIZE', '50').to_i.clamp(10, 100)
  MESSAGE_LIMIT = ENV.fetch('ROTTABRASIL_UAZAPI_RECONCILIATION_MESSAGE_LIMIT', '500').to_i.clamp(10, 500)
  MAX_CHAT_PAGES = ENV.fetch('ROTTABRASIL_UAZAPI_RECONCILIATION_MAX_PAGES', '20').to_i.clamp(1, 100)
  REQUEST_TIMEOUT = 20
  LOCK_TTL = 4.minutes
  CURSOR_KEY = 'rotta:uazapi:history-reconciliation:last-success-at'
  CURSOR_OVERLAP = 10.minutes

  def perform
    return if instance_token.blank? || webhook_token.blank?

    with_reconciliation_lock do
      cutoff = reconciliation_cutoff
      each_recent_chat(cutoff) do |chat|
        replay_missing_messages(chat, cutoff)
      end
      Redis::Alfred.set(CURSOR_KEY, Time.current.to_f)
    end
  rescue StandardError => e
    Rails.logger.error("[RottaUazapiReconciliation] class=#{e.class.name} error=#{e.message.to_s.first(200)}")
    raise
  end

  private

  def with_reconciliation_lock
    lock_key = 'rotta:uazapi:history-reconciliation:lock'
    lock_token = SecureRandom.uuid
    acquired = Redis::Alfred.set(lock_key, lock_token, nx: true, ex: LOCK_TTL.to_i)
    return unless acquired

    yield
  ensure
    Redis::Alfred.delete_if_equals(lock_key, lock_token) if acquired
  end

  def each_recent_chat(cutoff)
    MAX_CHAT_PAGES.times do |page|
      chats = response_records(
        uazapi_post('/chat/find', sort: '-wa_lastMsgTimestamp', limit: CHAT_PAGE_SIZE, offset: page * CHAT_PAGE_SIZE),
        %w[chats data records]
      )
      break if chats.empty?

      recent_chats = chats.select { |chat| recent?(chat_timestamp(chat), cutoff) }
      recent_chats.each { |chat| yield chat }
      break if chats.length < CHAT_PAGE_SIZE || recent_chats.length < chats.length
    end
  end

  def replay_missing_messages(chat, cutoff)
    chat_id = value_for_keys(chat, %w[wa_chatid chatid chatId chat_id jid remoteJid remote_jid])
    return if chat_id.blank? || chat_id.to_s.end_with?('@g.us')

    payload = uazapi_post('/message/find', chatid: chat_id, limit: MESSAGE_LIMIT)
    messages = response_records(payload, %w[messages data records])
    recent_messages = messages.select { |message| recent?(message_timestamp(message), cutoff) }
    provider_ids = recent_messages.flat_map { |message| message_source_ids(message) }.uniq
    existing_ids = Message.where(account_id: ACCOUNT_ID, source_id: provider_ids.flat_map { |id| [id, "uazapi:#{id}"] })
                          .pluck(:source_id).map { |id| id.delete_prefix('uazapi:') }.to_set
    recent_messages.sort_by { |message| message_timestamp(message) || Time.at(0) }.each do |message|
      # Recovery is for missing messages. Do not replay the same 72-hour history
      # into the web server every minute. Explicit edits/deletions still use
      # the webhook so their existing bubble can be updated.
      mutation = value_for_keys(message, %w[edited editedMessage edited_message editOf edit_of deleted revoked]).present? ||
                 value_for_keys(message, %w[type messageType]).to_s.match?(/edit|delet|revok|protocol/i)
      next if message_source_ids(message).any? { |id| existing_ids.include?(id) } && !mutation

      replay_message(message)
    end
  end

  def replay_message(message)
    response = http_request(
      webhook_uri,
      Net::HTTP::Post,
      { event: 'history', data: message, reconciliation: true },
      # Internal service traffic bypasses the TLS proxy. Without its protocol
      # header Rails redirects POSTs (308), so recovery never reaches the hook.
      { 'X-Forwarded-Proto' => 'https' }
    )
    return if response.code.to_i.between?(200, 299)

    raise "webhook replay failed with HTTP #{response.code}"
  end

  def message_provider_id(message)
    %w[message_id messageid id].each do |key|
      value = value_for_keys(message, [key])
      return value.to_s if value.present?
    end
    nil
  end

  def message_source_ids(message)
    # Older deliveries used UAZAPI's owner:messageid storage ID. Recognize
    # both forms so a canonical-ID fix never replays already saved history.
    [message_provider_id(message), value_for_keys(message, %w[id])].compact_blank.map(&:to_s).uniq
  end

  def uazapi_post(path, body)
    response = http_request(URI.parse("#{BASE_URL.chomp('/')}#{path}"), Net::HTTP::Post, body, 'token' => instance_token)
    raise "Uazapi #{path} failed with HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

    JSON.parse(response.body.presence || '{}')
  end

  def http_request(uri, request_class, body, headers = {})
    request = request_class.new(uri.request_uri)
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'
    headers.each { |key, value| request[key] = value }
    request.body = body.to_json

    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: REQUEST_TIMEOUT,
      read_timeout: REQUEST_TIMEOUT
    ) { |http| http.request(request) }
  end

  def webhook_uri
    token = URI.encode_www_form_component(webhook_token)
    URI.parse("#{CHATWOOT_INTERNAL_URL.chomp('/')}/webhooks/uazapi/#{token}/history")
  end

  def response_records(payload, preferred_keys)
    return payload.select { |item| item.is_a?(Hash) } if payload.is_a?(Array)
    return [] unless payload.is_a?(Hash)

    preferred_keys.each do |key|
      value = payload[key] || payload[key.to_sym]
      return value.select { |item| item.is_a?(Hash) } if value.is_a?(Array)
      nested = response_records(value, preferred_keys) if value.is_a?(Hash)
      return nested if nested.present?
    end

    []
  end

  def recent?(timestamp, cutoff)
    timestamp.nil? || timestamp >= cutoff
  end

  def reconciliation_cutoff
    last_success_at = parse_timestamp(Redis::Alfred.get(CURSOR_KEY))
    return LOOKBACK.ago unless last_success_at

    [last_success_at - CURSOR_OVERLAP, LOOKBACK.ago].max
  end

  def chat_timestamp(chat)
    parse_timestamp(value_for_keys(chat, %w[wa_lastMsgTimestamp lastMsgTimestamp timestamp updatedAt updated_at]))
  end

  def message_timestamp(message)
    parse_timestamp(value_for_keys(message, %w[timestamp messageTimestamp message_timestamp createdAt created_at sentAt sent_at]))
  end

  def parse_timestamp(value)
    return if value.blank?

    if value.to_s.match?(/\A\d+(?:\.\d+)?\z/)
      epoch = value.to_f
      epoch /= 1000 if epoch > 10_000_000_000
      return Time.zone.at(epoch)
    end

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def value_for_keys(node, keys)
    return unless node.is_a?(Hash)

    normalized = keys.map(&:downcase)
    node.each do |key, value|
      return value if normalized.include?(key.to_s.downcase) && !value.is_a?(Hash) && !value.is_a?(Array)
    end
    node.each_value do |value|
      found = value_for_keys(value, keys) if value.is_a?(Hash)
      return found if found.present?
    end
    nil
  end

  def instance_token
    ENV['ROTTABRASIL_UAZAPI_TOKEN'].presence || ENV['ROTTABRASIL_UAZAPI_INSTANCE_TOKEN'].presence
  end

  def webhook_token
    ENV['ROTTABRASIL_UAZAPI_WEBHOOK_TOKEN'].presence
  end
end
