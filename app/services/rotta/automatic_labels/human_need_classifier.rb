require 'json'
require 'net/http'

class Rotta::AutomaticLabels::HumanNeedClassifier
  ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions'.freeze
  MODEL = 'deepseek/deepseek-v4-flash-0731'.freeze
  MAX_TOKENS = 120
  TIMEOUT_SECONDS = 6
  MAX_MESSAGE_CHARS = 700
  MAX_CONTEXT_MESSAGES = 4

  Decision = Struct.new(:needs_human, :confidence, :reason, keyword_init: true) do
    def needs_human?
      needs_human == true
    end
  end

  class Error < StandardError; end

  def initialize(http_client: HTTParty, api_key: ENV['OPENROUTER_API_KEY'])
    @http_client = http_client
    @api_key = api_key.to_s.strip
  end

  def call(context)
    raise Error, 'OPENROUTER_API_KEY ausente' if @api_key.blank?

    response = @http_client.post(
      ENDPOINT,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@api_key}",
        'HTTP-Referer' => ENV.fetch('FRONTEND_URL', 'https://atendimento.via-cargo.com'),
        'X-Title' => 'Chatwoot Rotta Automatic Labels'
      },
      body: {
        model: MODEL,
        temperature: 0,
        max_tokens: MAX_TOKENS,
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: JSON.generate(sanitize_context(context)) }
        ]
      }.to_json,
      timeout: TIMEOUT_SECONDS
    )

    payload = response.parsed_response
    raise Error, "OpenRouter respondeu HTTP #{response.code}" unless response.success? && payload.is_a?(Hash)

    parse_decision(payload.dig('choices', 0, 'message', 'content').to_s)
  rescue JSON::ParserError => e
    raise Error, "Resposta inválida da DeepSeek: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Timeout::Error => e
    raise Error, "Tempo limite da DeepSeek: #{e.message}"
  end

  private

  def system_prompt
    <<~PROMPT
      Você é um classificador interno da Rotta Brasil Express. Decida somente se a última mensagem do cliente exige atendimento humano do Caio.
      Considere verdadeiro quando o cliente pede explicitamente um atendente, quer fechar/confirmar contratação, reclama de um problema,
      pede negociação, pagamento, disponibilidade operacional ou outra ação que a IA não deve concluir sozinha.
      Considere falso para saudações, confirmação de recebimento, perguntas operacionais que a IA consegue responder e mensagens sem pedido humano.
      Use somente o contexto recebido. Não crie fatos, não altere etiquetas e não responda ao cliente.
      Retorne SOMENTE JSON válido neste formato: {"needs_human":true,"confidence":0.0,"reason":"motivo curto"}.
      confidence deve estar entre 0 e 1. Se houver dúvida, use false e confiança baixa.
    PROMPT
  end

  def sanitize_context(context)
    {
      last_message: context[:last_message].to_s.first(MAX_MESSAGE_CHARS),
      recent_messages: Array(context[:recent_messages]).last(MAX_CONTEXT_MESSAGES).map do |item|
        {
          role: item[:role].to_s,
          content: item[:content].to_s.first(MAX_MESSAGE_CHARS)
        }
      end
    }
  end

  def parse_decision(content)
    json_text = content[/\{.*\}/m]
    raise Error, 'A DeepSeek não retornou JSON de classificação.' if json_text.blank?

    parsed = JSON.parse(json_text)
    needs_human = parsed['needs_human'] == true
    confidence = Float(parsed['confidence'])
    raise Error, 'Confiança retornada fora do intervalo permitido.' unless confidence.between?(0, 1)

    Decision.new(needs_human:, confidence:, reason: parsed['reason'].to_s.strip.first(240))
  rescue JSON::ParserError, TypeError, ArgumentError => e
    raise Error, "Classificação inválida da DeepSeek: #{e.message}"
  end
end
