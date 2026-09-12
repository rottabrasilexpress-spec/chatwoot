require 'json'
require 'net/http'
require 'uri'

module RottaCalculator
  class GoogleRoutesClient
    ENDPOINT = 'https://routes.googleapis.com/directions/v2:computeRoutes'.freeze

    def initialize(http_client: HTTParty)
      @http_client = http_client
    end

    def call(origin:, destination:)
      api_key = ENV['GOOGLE_ROUTES_API_KEY'].presence
      raise ConfigurationError, 'GOOGLE_ROUTES_API_KEY ausente' if api_key.blank?
      raise ArgumentError, 'Origem e destino são obrigatórios' if origin.blank? || destination.blank?

      response = @http_client.post(
        ENDPOINT,
        query: { key: api_key },
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'X-Goog-FieldMask' => 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline'
        },
        body: {
          origin: { address: origin },
          destination: { address: destination },
          travelMode: 'DRIVE',
          routingPreference: 'TRAFFIC_AWARE',
          languageCode: 'pt-BR',
          units: 'METRIC'
        }.to_json,
        timeout: 20
      )

      payload = response.parsed_response
      unless response.success? && payload.is_a?(Hash) && payload['routes'].is_a?(Array) && payload['routes'].first
        raise UpstreamError, "Google Routes respondeu HTTP #{response.code}"
      end

      route = payload['routes'].first
      {
        'distance_km' => (route['distanceMeters'].to_f / 1000).round(1),
        'duration_minutes' => parse_duration_minutes(route['duration']),
        'polyline' => route.dig('polyline', 'encodedPolyline')
      }
    rescue JSON::ParserError => e
      raise UpstreamError, "Resposta inválida do Google Routes: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Timeout::Error => e
      raise UpstreamError, "Falha de rede no Google Routes: #{e.message}"
    end

    private

    def parse_duration_minutes(duration)
      seconds = duration.to_s.delete_suffix('s').to_f
      (seconds / 60).ceil
    end
  end
end
