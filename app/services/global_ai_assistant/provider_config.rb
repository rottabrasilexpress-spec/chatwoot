class GlobalAiAssistant::ProviderConfig
  MODEL = 'deepseek/deepseek-v4-flash-0731'.freeze
  DEFAULT_API_BASE = 'https://openrouter.ai/api/v1'.freeze

  API_KEY_ENV_NAMES = %w[
    DEEPSEEK_API_KEY
    OPENROUTER_API_KEY
    ROTTA_GLOBAL_AI_API_KEY
  ].freeze
  API_BASE_ENV_NAMES = %w[
    DEEPSEEK_API_BASE
    OPENROUTER_API_BASE
    ROTTA_GLOBAL_AI_API_BASE
  ].freeze
  API_KEY_CONFIG_NAMES = %w[
    DEEPSEEK_API_KEY
    OPENROUTER_API_KEY
    ROTTA_GLOBAL_AI_API_KEY
  ].freeze
  API_BASE_CONFIG_NAMES = %w[
    DEEPSEEK_API_BASE
    OPENROUTER_API_BASE
    ROTTA_GLOBAL_AI_API_BASE
  ].freeze

  class << self
    def api_key
      env_value(API_KEY_ENV_NAMES) || config_value(API_KEY_CONFIG_NAMES)
    end

    def api_base
      configured = env_value(API_BASE_ENV_NAMES) || config_value(API_BASE_CONFIG_NAMES)
      normalized_base(configured.presence || DEFAULT_API_BASE)
    end

    private

    def env_value(names)
      names.lazy.map { |name| ENV[name].to_s.strip }.find(&:present?)
    end

    def config_value(names)
      names.lazy.map { |name| InstallationConfig.find_by(name: name)&.value.to_s.strip }.find(&:present?)
    end

    def normalized_base(value)
      base = value.to_s.strip.chomp('/')
      base.end_with?('/v1') ? base : "#{base}/v1"
    end
  end
end
