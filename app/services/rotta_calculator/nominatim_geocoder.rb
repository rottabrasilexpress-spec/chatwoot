require 'json'
require 'net/http'
require 'uri'

module RottaCalculator
  class NominatimGeocoder
    ENDPOINT = 'https://nominatim.openstreetmap.org/search'.freeze

    def call(address)
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form(q: "#{address}, Brasil", format: 'jsonv2', countrycodes: 'br', limit: 1)
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'
      request['User-Agent'] = 'RottaCalculator/1.0 (route fallback)'
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: 12) { |http| http.request(request) }
      data = JSON.parse(response.body)
      first = data.is_a?(Array) ? data.first : nil
      raise UpstreamError, "Nominatim não encontrou #{address}" unless response.is_a?(Net::HTTPSuccess) && first

      { 'latitude' => Float(first['lat']), 'longitude' => Float(first['lon']) }
    rescue JSON::ParserError, ArgumentError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise UpstreamError, "Falha no geocodificador de fallback: #{e.message}"
    end
  end
end
