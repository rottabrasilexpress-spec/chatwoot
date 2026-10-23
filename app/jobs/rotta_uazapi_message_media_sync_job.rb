# frozen_string_literal: true

require 'digest'

class RottaUazapiMessageMediaSyncJob < ApplicationJob
  include FileTypeHelper

  class MediaSyncError < StandardError; end

  queue_as :uazapi_sync
  self.enqueue_after_transaction_commit = :always

  BASE_URL = ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').freeze
  MAX_DOWNLOAD_BYTES = 40.megabytes
  REQUEST_TIMEOUT = 15
  ACCEPTABLE_CONTENT_TYPES = (Attachment::ACCEPTABLE_FILE_TYPES + Attachment::GENERIC_FILE_CONTENT_TYPES).freeze
  MEDIA_PLACEHOLDER = /\A\[(?:audio|image|video|document|sticker|arquivo)(?:message)?\]\z/i

  # The direct hook, native import and history recovery can see the same media.
  # Reserve a short enqueue window on the existing row, never create a message.
  def self.enqueue(message, provider_message_id, media_url = nil, media_type = nil)
    message.with_lock do
      next if message.attachments.exists?

      attributes = message.content_attributes.to_h
      queued_at = attributes['rotta_uazapi_media_enqueued_at']
      next if queued_at.present? && Time.iso8601(queued_at) > 5.minutes.ago

      perform_later(message.account_id, message.id, provider_message_id, media_url, media_type)
      message.update_columns(content_attributes: attributes.merge('rotta_uazapi_media_enqueued_at' => Time.current.iso8601))
    end
  end

  def perform(account_id, message_id, provider_message_id, media_url = nil, media_type = nil)
    message = find_message(account_id, message_id)
    return unless message
    return if attachment_already_synced?(message, provider_message_id, media_url)
    return if reuse_legacy_media(message, provider_message_id)

    synchronize_media(message, provider_message_id, media_url, media_type)
  rescue StandardError => e
    Rails.logger.warn(
      "[RottaMediaSync] message=#{message_id} account=#{account_id} " \
      "class=#{e.class.name} error=media_sync_failed"
    )
    raise
  end

  private

  def find_message(account_id, message_id)
    Message.where(account_id: account_id, id: message_id, message_type: %i[incoming outgoing], private: false).first
  end

  def synchronize_media(message, provider_message_id, media_url, media_type)
    media = { 'fileURL' => media_url, 'type' => media_type }
    media = fetch_provider_media(provider_message_id) if media['fileURL'].blank?
    file_url = media_value(media, %w[fileURL file_url url mediaUrl media_url])
    raise MediaSyncError, 'provider did not return a media URL' if file_url.blank?
    raise MediaSyncError, 'provider returned an invalid media URL' unless valid_http_url?(file_url)

    SafeFetch.fetch(
      file_url,
      max_bytes: MAX_DOWNLOAD_BYTES,
      allowed_content_type_prefixes: %w[image/ video/ audio/],
      allowed_content_types: ACCEPTABLE_CONTENT_TYPES
    ) do |downloaded_file|
      message.with_lock do
        next if attachment_already_synced?(message, provider_message_id, file_url)

        persist_attachment(message, provider_message_id, file_url, media, downloaded_file)
      end
    end
  end

  def reuse_legacy_media(message, provider_message_id)
    return false if provider_message_id.blank?

    # Historical native imports used owner:messageid. Reuse their stored file
    # only for this exact message, direction, account and conversation.
    source_ids = [provider_message_id, "uazapi:#{provider_message_id}"]
    suffix = "%:#{Message.sanitize_sql_like(provider_message_id)}"
    aliases = Message.where(account_id: message.account_id, conversation_id: message.conversation_id,
                            message_type: message.message_type, private: false)
                     .where.not(id: message.id)
                     .where('source_id IN (?) OR source_id LIKE ?', source_ids, suffix)
                     .includes(attachments: { file_attachment: :blob })
    existing = aliases.flat_map(&:attachments).find { |attachment| attachment.file.attached? }
    return false unless existing

    message.with_lock do
      next if message.attachments.exists?

      attachment = message.attachments.build(account_id: message.account_id, file_type: existing.file_type,
        meta: existing.meta.to_h.merge('uazapi_message_id' => provider_message_id.to_s))
      attachment.file.attach(existing.file.blob)
      attachment.save!
      if message.content.to_s.match?(MEDIA_PLACEHOLDER) && existing.message.content.present?
        message.update_columns(content: existing.message.content)
      end
      publish_media_update(message)
    end
    true
  end

  def attachment_already_synced?(message, provider_message_id, media_url)
    # Native imports may already have attached the file without UAZAPI metadata.
    return true if message.attachments.exists?

    return true if provider_message_id.present? && attachment_matches_provider_id?(message, provider_message_id)

    return false if media_url.blank?

    message.attachments.exists?(
      ["meta ->> 'uazapi_media_key' = ?", media_identity(media_url)]
    )
  end

  def attachment_matches_provider_id?(message, provider_message_id)
    message.attachments.exists?(
      ["meta ->> 'uazapi_message_id' = ?", provider_message_id.to_s]
    )
  end

  def fetch_provider_media(provider_message_id)
    return {} if provider_message_id.blank? || instance_token.blank?

    response = HTTParty.post(
      "#{BASE_URL.delete_suffix('/')}/message/download",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'token' => instance_token
      },
      body: { id: provider_message_id, return_link: true, return_base64: false }.to_json,
      timeout: REQUEST_TIMEOUT
    )
    raise MediaSyncError, "provider download returned HTTP #{response.code}" unless response.success?

    payload = response.parsed_response
    payload.is_a?(Hash) ? payload.stringify_keys : {}
  end

  def persist_attachment(message, provider_message_id, media_url, media, downloaded_file)
    content_type = downloaded_file.content_type.presence || media_value(media, %w[mimetype mimeType content_type])
    attachment = message.attachments.build(
      account_id: message.account_id,
      file_type: attachment_file_type(content_type, media_value(media, %w[type messageType])),
      meta: {
        'uazapi_message_id' => provider_message_id.to_s,
        'uazapi_media_key' => media_identity(media_url),
        'uazapi_content_type' => content_type.to_s
      }
    )
    attachment.file.attach(
      io: downloaded_file.tempfile,
      filename: safe_filename(downloaded_file.original_filename, provider_message_id),
      content_type: content_type
    )
    attachment.save!
    publish_media_update(message)
  end

  def publish_media_update(message)
    # Preserve real captions. These tokens are transport placeholders, not text.
    message.update_columns(content: nil) if message.content.to_s.match?(MEDIA_PLACEHOLDER)
    # Notify only after the file's after-commit upload is complete.
    ActiveRecord.after_all_transactions_commit { message.reload.send_update_event }
  end

  def attachment_file_type(content_type, provider_type)
    return file_type(content_type) if content_type.present? && content_type != 'application/octet-stream'

    normalized_type = provider_type.to_s.downcase
    return :image if normalized_type.include?('image')
    return :video if normalized_type.include?('video')
    return :audio if normalized_type.include?('audio')

    :file
  end

  def media_value(media, keys)
    keys.each do |key|
      value = media[key] || media[key.to_sym]
      return value.to_s.strip if value.present? && !value.is_a?(Hash) && !value.is_a?(Array)
    end
    nil
  end

  def safe_filename(filename, provider_message_id)
    normalized = File.basename(filename.to_s).gsub(/[^\p{Alnum}._-]/, '_').presence
    (normalized || "uazapi-#{provider_message_id}")[0, 255]
  end

  def media_identity(media_url)
    "url:#{Digest::SHA256.hexdigest(media_url.to_s)}"
  end

  def valid_http_url?(value)
    uri = URI.parse(value.to_s)
    %w[http https].include?(uri.scheme) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def instance_token
    ENV['ROTTABRASIL_UAZAPI_TOKEN'].presence || ENV['ROTTABRASIL_UAZAPI_INSTANCE_TOKEN'].presence
  end
end

RottaUazapiMessageMediaSyncJob.prepend_mod_with('RottaUazapiMessageMediaSyncJob')
