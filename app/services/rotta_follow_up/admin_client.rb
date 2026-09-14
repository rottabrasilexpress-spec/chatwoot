module RottaFollowUp
  class AdminClient
    ADMIN_URL = 'https://saas.via-cargo.com/webhook/rotta-chatwoot-followup-admin-v1'.freeze

    Response = Struct.new(:status, :body, keyword_init: true) do
      def success?
        status.to_i.between?(200, 299) && body.is_a?(Hash) && body['ok'] != false
      end
    end

    def self.request(payload)
      response = HTTParty.post(
        ADMIN_URL,
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'
        },
        body: payload.to_h.stringify_keys.to_json,
        timeout: 20
      )

      Response.new(status: response.code.to_i, body: JSON.parse(response.body))
    rescue JSON::ParserError => e
      raise InvalidResponse, 'A resposta do painel de follow-up não era JSON válido.', cause: e
    rescue StandardError => e
      raise RequestError, 'Não foi possível comunicar com o painel de follow-up.', cause: e
    end

    class Error < StandardError; end
    class InvalidResponse < Error; end
    class RequestError < Error; end
  end
end
