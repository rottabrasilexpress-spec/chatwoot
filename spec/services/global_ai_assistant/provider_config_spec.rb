require 'rails_helper'

RSpec.describe GlobalAiAssistant::ProviderConfig do
  describe '.api_key' do
    around do |example|
      original = ENV.to_h.slice(*described_class::API_KEY_ENV_NAMES)
      described_class::API_KEY_ENV_NAMES.each { |name| ENV.delete(name) }
      example.run
    ensure
      described_class::API_KEY_ENV_NAMES.each { |name| ENV.delete(name) }
      original.each { |name, value| ENV[name] = value }
    end

    it 'uses the same OpenRouter key as the individual calculator and ignores DeepSeek/Captain fallbacks' do
      create(:installation_config, name: 'CAPTAIN_OPEN_AI_API_KEY', value: 'captain-key')
      create(:installation_config, name: 'DEEPSEEK_API_KEY', value: 'deepseek-key')
      ENV['OPENROUTER_API_KEY'] = 'openrouter-key'

      expect(described_class.api_key).to eq('openrouter-key')
    end

    it 'prefers the live environment secret over persisted configuration' do
      create(:installation_config, name: 'OPENROUTER_API_KEY', value: 'persisted-key')
      ENV['OPENROUTER_API_KEY'] = 'live-key'

      expect(described_class.api_key).to eq('live-key')
    end
  end

  describe '.api_base' do
    it 'normalizes the OpenRouter base without reading Captain endpoint settings' do
      expect(described_class.api_base).to eq('https://openrouter.ai/api/v1')
    end
  end
end
