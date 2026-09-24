require 'json'
require 'openssl'
require 'uri'

module RottaAiStatus
  class Client
    INSTANCE = 'rotta'.freeze
    MAX_BATCH_SIZE = 100
    OPEN_TIMEOUT_SECONDS = 3
    READ_TIMEOUT_SECONDS = 5
    MIN_SECRET_LENGTH = 32

    def initialize(url: ENV['ROTTA_AI_STATUS_WEBHOOK_URL'], secret: ENV['ROTTA_AI_STATUS_HMAC_SECRET'], connection: nil)
      @url = url
      @secret = secret
      @connection = connection || build_connection
    end

    def statuses_for(remote_jids)
      jids = remote_jids.uniq.sort
      return {} if jids.empty? || !configured?

      timestamp = Time.current.to_i.to_s
      body = JSON.generate(instance: INSTANCE, remote_jids: jids)
      response = @connection.post(@url, body, request_headers(timestamp, jids))
      raise Faraday::Error, "n8n returned HTTP #{response.status}" unless response.success?

      parse_statuses(response.body)
    rescue Faraday::Error, JSON::ParserError, TypeError, URI::InvalidURIError => e
      Rails.logger.warn("[RottaAiStatus] Status lookup unavailable (#{e.class})")
      {}
    end

    private

    def configured?
      return false if @secret.blank? || @secret.bytesize < MIN_SECRET_LENGTH

      uri = URI.parse(@url.to_s)
      uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def build_connection
      Faraday.new do |faraday|
        faraday.options.open_timeout = OPEN_TIMEOUT_SECONDS
        faraday.options.timeout = READ_TIMEOUT_SECONDS
      end
    end

    def request_headers(timestamp, remote_jids)
      canonical = [timestamp, INSTANCE, *remote_jids].join("\n")
      signature = OpenSSL::HMAC.hexdigest('SHA256', @secret, canonical)

      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'X-Rotta-Status-Timestamp' => timestamp,
        'X-Rotta-Status-Signature' => "sha256=#{signature}"
      }
    end

    def parse_statuses(response_body)
      payload = JSON.parse(response_body)
      return {} unless payload.is_a?(Hash)

      Array(payload['statuses']).each_with_object({}) do |status, result|
        next unless status.is_a?(Hash)

        state = status['state']
        remote_jid = status['remote_jid']
        next unless %w[active blocked].include?(state)
        next unless remote_jid.is_a?(String)

        result[remote_jid] = state
      end
    end
  end
end
