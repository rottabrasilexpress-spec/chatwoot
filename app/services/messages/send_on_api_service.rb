class Messages::SendOnApiService < Base::SendOnChannelService
  UAZAPI_PATH = '/send/text'.freeze

  private

  def channel_class
    Channel::Api
  end

  def perform_reply
    return fail_message('Mídia enviada pelo Chatwoot ainda não está habilitada neste canal') if message.attachments.present?

    content_attributes = message.content_attributes.to_h.with_indifferent_access
    body = {
      number: recipient_number,
      text: message.outgoing_content.to_s,
      delay: 2,
      readchat: true,
      linkPreview: false
    }
    body[:forward] = true if content_attributes[:rotta_forwarded]
    body[:replyid] = content_attributes[:in_reply_to_external_id] if content_attributes[:in_reply_to_external_id].present?
    body[:track_source] = 'chatwoot'
    body[:track_id] = "message-#{message.id}"

    response = HTTParty.post(
      "#{uazapi_base_url}#{UAZAPI_PATH}",
      headers: uazapi_headers,
      body: body.to_json,
      timeout: 30
    )

    return fail_message(provider_error(response)) unless response.success?

    provider_id = provider_message_id(response)
    message.update!(source_id: provider_id) if provider_id.present?
    Rails.logger.info("[ROTTABRASIL_API] message=#{message.id} sent provider_id_present=#{provider_id.present?}")
  rescue StandardError => e
    fail_message("Falha ao enviar pela Uazapi: #{e.message}")
  end

  def uazapi_base_url
    ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').delete_suffix('/')
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

  def fail_message(error)
    message.update!(status: :failed, external_error: error.to_s.truncate(500))
    Rails.logger.error("[ROTTABRASIL_API] message=#{message.id} failed #{error}")
  end
end
