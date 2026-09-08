# frozen_string_literal: true

require 'net/http'
require 'uri'

# Keeps WhatsApp contact photos available in Chatwoot without exposing the
# Uazapi credential to the browser. Uazapi returns a short-lived WhatsApp URL;
# AvatarFromUrlJob downloads it into Chatwoot Active Storage, so the UI keeps
# working even after the provider URL expires.
class RottaUazapiContactAvatarSyncJob < ApplicationJob
  queue_as :housekeeping

  ACCOUNT_ID = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i
  BASE_URL = ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').freeze
  BATCH_SIZE = ENV.fetch('ROTTABRASIL_UAZAPI_AVATAR_BATCH_SIZE', '50').to_i.clamp(1, 250)
  SYNC_INTERVAL = ENV.fetch('ROTTABRASIL_UAZAPI_AVATAR_SYNC_HOURS', '12').to_i.clamp(1, 168).hours
  EVENT_SYNC_COOLDOWN = 1.minute
  REQUEST_TIMEOUT = 12

  IMAGE_KEYS = %w[
    image imagePreview profilePicUrl profilePictureUrl profile_picture_url
    profile_pic_url pictureUrl picture_url avatarUrl avatar_url thumbnail
  ].map { |key| key.delete('_').downcase }.freeze

  def perform(account_id = ACCOUNT_ID, contact_id = nil)
    return if instance_token.blank?

    contacts_scope(account_id, contact_id).each do |contact|
      next if contact_id.present? && event_sync_recent?(contact)

      sync_contact(contact)
    end
  end

  private

  def instance_token
    ENV['ROTTABRASIL_UAZAPI_TOKEN'].presence || ENV['ROTTABRASIL_UAZAPI_INSTANCE_TOKEN'].presence
  end

  def contacts_scope(account_id, contact_id)
    scope = Contact.where(account_id: account_id)
                   .where.not(phone_number: nil)
                   .where.not(phone_number: '')

    return scope.where(id: contact_id) if contact_id.present?

    cutoff = SYNC_INTERVAL.ago.iso8601
    scope.where(
      "contacts.additional_attributes ->> 'rotta_uazapi_avatar_sync_at' IS NULL OR " \
      "NULLIF(contacts.additional_attributes ->> 'rotta_uazapi_avatar_sync_at', '')::timestamptz < ?",
      cutoff
    ).order(
      Arel.sql("COALESCE(contacts.additional_attributes ->> 'rotta_uazapi_avatar_sync_at', '1970-01-01T00:00:00Z') ASC")
    ).limit(BATCH_SIZE)
  end

  def sync_contact(contact)
    number = normalize_phone(contact.phone_number)
    return if number.blank?

    response = fetch_chat_details(number)
    image_url = extract_image_url(response)
    mark_sync(contact, image_url.present? ? 'found' : 'missing')
    return if image_url.blank?

    previous_blob_id = contact.avatar.blob&.id
    Avatar::AvatarFromUrlJob.perform_now(contact, image_url)
    contact.reload

    return unless contact.avatar.attached?
    return if previous_blob_id.present? && previous_blob_id == contact.avatar.blob&.id

    dispatch_contact_update(contact)
  rescue StandardError => e
    mark_sync(contact, 'error') if contact&.persisted?
    Rails.logger.warn("[RottaAvatarSync] contact=#{contact&.id} #{e.class}: #{e.message}")
  end

  def event_sync_recent?(contact)
    last_sync_at = contact.additional_attributes&.[]('rotta_uazapi_avatar_sync_at')
    return false if last_sync_at.blank?

    Time.zone.parse(last_sync_at) >= EVENT_SYNC_COOLDOWN.ago
  rescue ArgumentError, TypeError
    false
  end

  def fetch_chat_details(number)
    uri = URI.parse("#{BASE_URL.chomp('/')}/chat/details")
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'
    request['token'] = instance_token
    request.body = { number: number }.to_json

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: REQUEST_TIMEOUT,
      read_timeout: REQUEST_TIMEOUT
    ) { |http| http.request(request) }

    return {} unless response.code.to_i.between?(200, 299)

    JSON.parse(response.body.presence || '{}')
  end

  def extract_image_url(payload)
    values = []
    collect_image_values(payload, values)
    values.find { |value| valid_http_url?(value) }
  end

  def collect_image_values(node, values)
    case node
    when Hash
      node.each do |key, value|
        normalized_key = key.to_s.delete('_').downcase
        values << value if IMAGE_KEYS.include?(normalized_key) && value.is_a?(String)
        collect_image_values(value, values)
      end
    when Array
      node.each { |value| collect_image_values(value, values) }
    end
  end

  def valid_http_url?(value)
    uri = URI.parse(value.to_s)
    %w[http https].include?(uri.scheme) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.presence
  end

  def mark_sync(contact, status)
    attributes = (contact.additional_attributes || {}).to_h.stringify_keys
    attributes['rotta_uazapi_avatar_sync_at'] = Time.current.iso8601
    attributes['rotta_uazapi_avatar_sync_status'] = status
    contact.update_columns(additional_attributes: attributes) # rubocop:disable Rails/SkipsModelValidations
  end

  def dispatch_contact_update(contact)
    Rails.configuration.dispatcher.dispatch(
      ::CONTACT_UPDATED,
      Time.zone.now,
      contact: contact,
      changed_attributes: { 'avatar' => [nil, contact.avatar_url] }
    )
  end
end
