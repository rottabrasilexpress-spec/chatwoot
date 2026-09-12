module RottaCalculator
  class ResilientRoutesClient
    def initialize(primary: GoogleRoutesClient.new, fallback: OsrmRoutesClient.new)
      @primary = primary
      @fallback = fallback
    end

    def call(origin:, destination:)
      @primary.call(origin: origin, destination: destination).merge('provider' => 'google-routes', 'tolls' => 0.0, 'toll_status' => 'disabled')
    rescue ConfigurationError, UpstreamError => primary_error
      @fallback.call(origin: origin, destination: destination).merge('fallback_reason' => primary_error.message)
    end
  end
end
