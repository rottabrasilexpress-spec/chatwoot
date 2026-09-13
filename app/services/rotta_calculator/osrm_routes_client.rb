require 'json'
require 'net/http'
require 'uri'

module RottaCalculator
  class OsrmRoutesClient
    ENDPOINT = 'https://router.project-osrm.org/route/v1/driving'.freeze
    OPEN_TIMEOUT = 4
    READ_TIMEOUT = 7

    def initialize(geocoder: NominatimGeocoder.new)
      @geocoder = geocoder
    end

    def call(origin:, destination:)
      raise ArgumentError, 'Origem e destino são obrigatórios' if origin.blank? || destination.blank?
      # Nominatim is the slowest part of the unauthenticated fallback. The
      # lookups are independent, so perform them concurrently and keep the
      # same deterministic route request and response contract.
      origin_lookup = Thread.new { @geocoder.call(origin) }
      destination_lookup = Thread.new { @geocoder.call(destination) }
      origin_point = origin_lookup.value
      destination_point = destination_lookup.value
      uri = URI("#{ENDPOINT}/#{origin_point['longitude']},#{origin_point['latitude']};#{destination_point['longitude']},#{destination_point['latitude']}")
      uri.query = URI.encode_www_form(overview: 'full', geometries: 'polyline', alternatives: 'false', steps: 'false')
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }
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
    rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise UpstreamError, "Falha na rota de fallback: #{e.message}"
    end
  end
end
