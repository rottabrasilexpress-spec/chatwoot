class Messages::UazapiActionService
  class ProviderError < StandardError; end

  ACTION_PATHS = {
    delete: '/message/delete',
    edit: '/message/edit',
    pin: '/message/pin',
    react: '/message/react'
  }.freeze

  pattr_initialize [:message!, :action!, :text, :emoji, :pin, :duration]

  def perform
    validate_action!

    response = HTTParty.post(
      "#{uazapi_base_url}#{ACTION_PATHS.fetch(action)}",
      headers: uazapi_headers,
      body: payload.to_json,
      timeout: 30
    )

    raise ProviderError, provider_error(response) unless response.success?

    response.parsed_response
  rescue ProviderError
    raise
  rescue StandardError => e
    raise ProviderError, "Falha ao executar ação na Uazapi: #{e.message}"
  end

  def self.configured?
    ENV['ROTTABRASIL_UAZAPI_TOKEN'].presence || ENV['ROTTABRASIL_UAZAPI_INSTANCE_TOKEN'].presence
  end

  private

  delegate :conversation, to: :message

  def validate_action!
    raise ProviderError, 'Ação de mensagem não suportada.' unless ACTION_PATHS.key?(action)
    raise ProviderError, 'Esta ação exige uma mensagem de texto.' if action == :edit && text.blank?
    raise ProviderError, 'Mensagem sem ID externo da Uazapi.' if provider_message_id.blank?
  end

  def payload
    case action
    when :delete
      { id: provider_message_id }
    when :edit
      { id: provider_message_id, text: text.to_s }
    when :pin
      { id: provider_message_id, pin: pin != false, duration: normalized_duration }
    when :react
      { number: recipient_number, text: emoji.to_s, id: provider_message_id }
    end
  end

  def provider_message_id
    message.source_id.presence || message.additional_attributes&.[]('uazapi_message_id').presence
  end

  def normalized_duration
    value = duration.to_i
    [1, 7, 30].include?(value) ? value : 30
  end

  def recipient_number
    source_id = conversation.contact_inbox.source_id.to_s.strip
    return source_id if source_id.end_with?('@g.us', '@newsletter', '@lid', '@s.whatsapp.net')

    digits = source_id.gsub(/\D/, '')
    raise ProviderError, 'Contato sem número WhatsApp válido.' if digits.blank?

    digits
  end

  def uazapi_base_url
    ENV.fetch('ROTTABRASIL_UAZAPI_BASE_URL', 'https://transportadoras.uazapi.com').delete_suffix('/')
  end

  def uazapi_headers
    token = ENV['ROTTABRASIL_UAZAPI_TOKEN'].presence || ENV.fetch('ROTTABRASIL_UAZAPI_INSTANCE_TOKEN')

    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'token' => token
    }
  end

  def provider_error(response)
    body = response.parsed_response
    detail = if body.is_a?(Hash)
               body['error'] || body['message'] || body.dig('response', 'message')
             end

    "Uazapi recusou a ação (HTTP #{response.code})#{detail.present? ? ": #{detail}" : ''}"
  end
end
