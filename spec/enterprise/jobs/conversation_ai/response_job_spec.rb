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

  it 'persists an answer only when the webhook envelope belongs to the thread' do
    user = instance_double(User)
    users = instance_double(ActiveRecord::Relation, find: user)
    account = instance_double(Account, users: users)
    conversation = instance_double(Conversation, display_id: 2165, account_id: 1)
    messages = instance_double(ActiveRecord::Associations::CollectionProxy)
    thread = instance_double(
      CopilotThread,
      id: 44,
      account: account,
      conversation: conversation,
      copilot_messages: messages
    )
    relation = instance_double(ActiveRecord::Relation, find: thread)
    response = instance_double(
      HTTParty::Response,
      code: 200,
      success?: true,
      parsed_response: {
        'answer' => 'Resposta vinculada',
        'request_id' => 'req-123',
        'copilot_thread_id' => 44,
        'conversation_id' => 2165,
        'account_id' => 1
      }
    )

    allow(SecureRandom).to receive(:uuid).and_return('req-123')
    allow(CopilotThread).to receive(:includes).with(:account, :conversation).and_return(relation)
    expect(ConversationAi::ContextBuilder).to receive(:new).with(
      conversation: conversation,
      user: user,
      question: 'teste',
      request_id: 'req-123',
      copilot_thread_id: 44
    ).and_return(
      instance_double(ConversationAi::ContextBuilder, payload: { request_id: 'req-123' })
    )
    allow(HTTParty).to receive(:post).and_return(response)
    expect(messages).to receive(:create!).with(
      message_type: :assistant,
      message: hash_including(content: 'Resposta vinculada')
    )

    job.perform(copilot_thread_id: 44, user_id: 17, message: 'teste')
  end

  it 'rejects a response correlated to another conversation' do
    thread = instance_double(CopilotThread, id: 44)
    conversation = instance_double(Conversation, display_id: 2165, account_id: 1)

    expect do
      job.send(
        :validate_response_metadata!,
        {
          'request_id' => 'other-request',
          'copilot_thread_id' => 44,
          'conversation_id' => 2165,
          'account_id' => 1
        },
        request_id: 'req-123',
        copilot_thread: thread,
        conversation: conversation
      )
    end.to raise_error(/vínculo inválido/)
  end

  it 'does not persist a cross-conversation answer when the full job runs' do
    user = instance_double(User)
    users = instance_double(ActiveRecord::Relation, find: user)
    account = instance_double(Account, users: users)
    conversation = instance_double(Conversation, display_id: 2165, account_id: 1)
    messages = instance_double(ActiveRecord::Associations::CollectionProxy)
    thread = instance_double(
      CopilotThread,
      id: 44,
      account: account,
      conversation: conversation,
      copilot_messages: messages
    )
    relation = instance_double(ActiveRecord::Relation, find: thread)
    response = instance_double(
      HTTParty::Response,
      code: 200,
      success?: true,
      parsed_response: {
        'answer' => 'Resposta cruzada que não pode ser persistida',
        'request_id' => 'other-request',
        'copilot_thread_id' => 44,
        'conversation_id' => 2165,
        'account_id' => 1
      }
    )

    allow(SecureRandom).to receive(:uuid).and_return('req-123')
    allow(CopilotThread).to receive(:includes).with(:account, :conversation).and_return(relation)
    allow(ConversationAi::ContextBuilder).to receive(:new).and_return(
      instance_double(ConversationAi::ContextBuilder, payload: { request_id: 'req-123' })
    )
    allow(HTTParty).to receive(:post).and_return(response)
    allow(messages).to receive(:create!)

    job.perform(copilot_thread_id: 44, user_id: 17, message: 'teste')

    expect(messages).to have_received(:create!).with(
      message_type: :assistant,
      message: { content: I18n.t('captain.conversation_ai.failed') }
    )
    expect(messages).not_to have_received(:create!).with(
      message_type: :assistant,
      message: hash_including(content: 'Resposta cruzada que não pode ser persistida')
    )
  end
end
