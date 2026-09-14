require 'json'
require 'net/http'

class GlobalAiAssistant::OpenRouterClient
  MODEL = GlobalAiAssistant::ProviderConfig::MODEL
  DEFAULT_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions'.freeze
  MAX_TOKENS = 1200

  def initialize(api_key:, api_base:)
    @api_key = api_key.to_s.strip
    @endpoint = "#{api_base.to_s.chomp('/')}/chat/completions"
  end

  def call(messages)
    raise ArgumentError, 'A credencial DeepSeek/OpenRouter da IA global não está configurada.' if @api_key.blank?

    response = HTTParty.post(
      @endpoint.presence || DEFAULT_ENDPOINT,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_key}",
        'HTTP-Referer' => ENV.fetch('FRONTEND_URL', 'https://atendimento.via-cargo.com'),
        'X-Title' => 'Chatwoot Rotta Global AI'
      },
      body: {
        model: MODEL,
        temperature: 0.1,
        max_tokens: MAX_TOKENS,
        messages: messages
      }.to_json,
      timeout: 30
    )

    payload = response.parsed_response
    return payload.dig('choices', 0, 'message', 'content').to_s if response.success? && payload.is_a?(Hash)

    raise "OpenRouter respondeu HTTP #{response.code}: #{error_message(payload)}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Timeout::Error => e
    raise "Falha de rede no OpenRouter: #{e.message}"
  end

  private

  def error_message(payload)
    message = payload.is_a?(Hash) ? payload.dig('error', 'message') : nil
    message.to_s.strip.presence || 'resposta sem detalhes'
  end
end
