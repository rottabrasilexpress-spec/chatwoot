module RottaAi
  class OpenRouterConfig
    MODEL = 'deepseek/deepseek-v4-flash-0731'.freeze
    API_BASE = 'https://openrouter.ai/api/v1'.freeze

    class << self
      def api_key
        ENV['OPENROUTER_API_KEY'].to_s.strip.presence
      end

      def api_base
        API_BASE
      end

      def model
        configured_model = ENV['OPENROUTER_MODEL'].to_s.strip.presence
        if configured_model.present? && configured_model != MODEL
          raise ArgumentError, "OPENROUTER_MODEL deve ser #{MODEL}"
        end

        MODEL
      end
    end
  end
end
