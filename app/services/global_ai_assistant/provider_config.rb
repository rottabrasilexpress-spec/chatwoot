class GlobalAiAssistant::ProviderConfig
  MODEL = RottaAi::OpenRouterConfig::MODEL
  DEFAULT_API_BASE = RottaAi::OpenRouterConfig::API_BASE
  API_KEY_ENV_NAMES = %w[OPENROUTER_API_KEY].freeze
  API_BASE_ENV_NAMES = [].freeze
  API_KEY_CONFIG_NAMES = [].freeze
  API_BASE_CONFIG_NAMES = [].freeze

  class << self
    def api_key
      RottaAi::OpenRouterConfig.api_key
    end

    def api_base
      RottaAi::OpenRouterConfig.api_base
    end
  end
end
