require 'json'
require 'net/http'
require 'uri'

module RottaCalculator
  class OsrmRoutesClient
    ENDPOINT = 'https://router.project-osrm.org/route/v1/driving'.freeze

    def initialize(geocoder: NominatimGeocoder.new)
      @geocoder = geocoder
    end

    def call(origin:, destination:)
      raise ArgumentError, 'Origem e destino são obrigatórios' if origin.blank? || destination.blank?
      origin_point = @geocoder.call(origin)
      destination_point = @geocoder.call(destination)
      uri = URI("#{ENDPOINT}/#{origin_point['longitude']},#{origin_point['latitude']};#{destination_point['longitude']},#{destination_point['latitude']}")
      uri.query = URI.encode_www_form(overview: 'full', geometries: 'polyline', alternatives: 'false', steps: 'false')
      response = Net::HTTP.get_response(uri)
      payload = JSON.parse(response.body)
      route = payload['routes']&.first
      raise UpstreamError, "OSRM respondeu HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess) && route

      {
        'distance_km' => (route['distance'].to_f / 1000).round(1),
        'duration_minutes' => (route['duration'].to_f / 60).ceil,
        'polyline' => route['geometry'],
        'provider' => 'osm-osrm-fallback',
        'tolls' => 0.0,
        'toll_status' => 'disabled'
      }
    rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise UpstreamError, "Falha na rota de fallback: #{e.message}"
    end
  end
end
