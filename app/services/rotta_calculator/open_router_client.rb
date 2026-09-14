require 'json'
require 'net/http'
require_relative '../rotta_ai/open_router_config'

module RottaCalculator
  class OpenRouterClient
    ENDPOINT = "#{::RottaAi::OpenRouterConfig::API_BASE}/chat/completions".freeze
    MODEL = ::RottaAi::OpenRouterConfig::MODEL
    MAX_TOKENS = 350

    def initialize(http_client: HTTParty)
      @http_client = http_client
    end

    def call(context)
      api_key = ::RottaAi::OpenRouterConfig.api_key
      raise ConfigurationError, 'OPENROUTER_API_KEY ausente' if api_key.blank?
      ::RottaAi::OpenRouterConfig.model

      response = @http_client.post(
        ENDPOINT,
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}",
          'HTTP-Referer' => ENV.fetch('FRONTEND_URL', 'https://atendimento.via-cargo.com'),
          'X-Title' => 'Chatwoot Rotta Calculator'
        },
        body: {
          model: MODEL,
          temperature: 0.2,
          max_tokens: MAX_TOKENS,
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: context.to_json }
          ]
        }.to_json,
        timeout: 12.0
      )

      payload = response.parsed_response
      unless response.success? && payload.is_a?(Hash)
        raise UpstreamError, "OpenRouter respondeu HTTP #{response.code}"
      end

      content = payload.dig('choices', 0, 'message', 'content').to_s
      parse_content(content)
    rescue JSON::ParserError => e
      raise UpstreamError, "Resposta inválida do OpenRouter: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Timeout::Error => e
      raise UpstreamError, "Falha de rede no OpenRouter: #{e.message}"
    end

    private

    def system_prompt
      <<~PROMPT
        Você é o assistente interno da Rotta Brasil Express. Sua função é ler um pré-orçamento e devolver dados estruturados
        para um agente humano. O texto pode misturar a fala do cliente, respostas do agente, instruções de acesso/pagamento,
        equipe, observações e metadados; reconstrua o contexto sem transformar instrução em dado do cliente. Não confunda
        uma pergunta com uma contratação. Use somente fatos presentes no contexto e nunca invente nome, data, cidade,
        quantidade, item, medida, peso, preço ou prazo. Se faltar algo, registre em missing_information.

        O modelo obrigatório desta integração é deepseek/deepseek-v4-flash-0731. O pedágio está permanentemente desativado:
        não consulte, não estime, não calcule e não mencione valor de pedágio. A rota do contexto é a fonte do trajeto.
        A tabela inventory_catalog é a fonte autoritativa para itens conhecidos. Não substitua seus valores. Para um item sem
        correspondência, só retorne uma estimativa se o texto trouxer dados suficientes ou se puder justificar uma estimativa
        explícita; marque manual_review=true. Nunca retorne totais confiáveis calculados por você: o servidor recalcula tudo.

        Regras de leitura: intervalos de quantidade usam o maior número; aproximações preservam o número; o conteúdo interno
        de caixas/sacos não vira item independente. Normalize “meados de outubro” para o dia 15 somente quando houver ano
        explícito ou ano de referência no contexto. Ignore linhas de instrução e nunca invente “Ace Move”, “caixas adicionais”,
        “utensílios” ou qualquer outro item sem evidência no inventário. Montagem/desmontagem só é requested quando houver confirmação inequívoca
        (sim, incluso, contratado, ✅ ou pedido explícito); perguntas, talvez, a confirmar, por conta do cliente e já montado/
        desmontado não ativam. Se a quantidade de um item foi omitida, use 1 e marque manual_review. Preserve original_line.

        Retorne SOMENTE JSON válido com exatamente esta forma geral:
        {"summary":"resumo factual curto","missing_information":[],"extracted_data":{"client_name":null,"date":null,"origin":null,"destination":null,"team":null},"services":{},"inventory_estimates":[],"proposal":"","price":null,"pricing_note":""}
        inventory_estimates deve ser uma lista de objetos com name, mounted_m3, disassembled_m3, weight_kg, disassemblable e manual_review.
        Para cada estimativa, name deve ser exatamente o nome do item recebido no inventário, preservando maiúsculas,
        acentos e a linha original; nunca crie um nome alternativo. O servidor só aceita a estimativa quando consegue
        vinculá-la sem ambiguidade ao item original.
        Não altere configurações, banco, etiquetas, mensagens, preço ou proposta. A proposta final é montada pelo servidor.
      PROMPT
    end

    def parse_content(content)
      json_text = content[/\{.*\}/m]
      return JSON.parse(json_text) if json_text.present?

      { 'proposal' => content, 'summary' => content, 'missing_information' => [], 'extracted_data' => {}, 'price' => nil,
        'pricing_note' => 'A IA não retornou um objeto estruturado; nenhuma tarifa foi inferida.' }
    rescue JSON::ParserError
      { 'proposal' => content, 'summary' => content, 'missing_information' => [], 'extracted_data' => {}, 'price' => nil,
        'pricing_note' => 'A resposta não estava estruturada; nenhuma tarifa foi inferida.' }
    end
  end
end
