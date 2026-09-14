class GlobalAiAssistant::ProviderConfig
  MODEL = 'deepseek/deepseek-v4-flash-0731'.freeze
  DEFAULT_API_BASE = 'https://openrouter.ai/api/v1'.freeze
  API_KEY_ENV_NAMES = %w[OPENROUTER_API_KEY].freeze
  API_BASE_ENV_NAMES = [].freeze
  API_KEY_CONFIG_NAMES = [].freeze
  API_BASE_CONFIG_NAMES = [].freeze

  class << self
    def api_key
      ENV['OPENROUTER_API_KEY'].to_s.strip.presence
    end

    def api_base
      DEFAULT_API_BASE
    end
  end
end
