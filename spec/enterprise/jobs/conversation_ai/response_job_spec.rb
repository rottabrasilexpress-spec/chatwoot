require 'rails_helper'

RSpec.describe ConversationAi::ResponseJob, type: :job do
  let(:job) { described_class.new }

  around do |example|
    previous_secret = ENV['ROTTA_CONVERSATION_AI_WEBHOOK_SECRET']
    ENV['ROTTA_CONVERSATION_AI_WEBHOOK_SECRET'] = 'test-only-secret'
    example.run
  ensure
    ENV['ROTTA_CONVERSATION_AI_WEBHOOK_SECRET'] = previous_secret
  end

  it 'sends the dedicated server-side webhook secret' do
    expect(job.send(:webhook_headers)).to include(
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'X-Rotta-Conversation-AI-Secret' => 'test-only-secret'
    )
  end

  it 'fails closed when the webhook secret is not configured' do
    ENV.delete('ROTTA_CONVERSATION_AI_WEBHOOK_SECRET')

    expect { job.send(:webhook_headers) }.to raise_error(KeyError)
  end

  it 'keeps accepting legacy queued jobs with conversation_id' do
    expect(described_class.instance_method(:perform).parameters).to include(
      [:key, :conversation_id]
    )
  end
end
