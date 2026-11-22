require 'rails_helper'

RSpec.describe ConversationAi::ResponseJob, type: :job do
  let(:job) { described_class.new }
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:thread) { create(:captain_copilot_thread, account: account, user: user, private_conversation: conversation) }
  let(:question) do
    thread.copilot_messages.create!(message_type: :user, message: { content: 'Teste de leitura', author_id: user.id })
  end

  it 'sends the dedicated server-side webhook secret' do
    with_modified_env ROTTA_CONVERSATION_AI_WEBHOOK_SECRET: 'test-only-secret' do
      expect(job.send(:webhook_headers)).to include(
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'X-Rotta-Conversation-AI-Secret' => 'test-only-secret'
      )
    end
  end

  it 'fails closed when the webhook secret is not configured' do
    with_modified_env ROTTA_CONVERSATION_AI_WEBHOOK_SECRET: nil do
      expect { job.send(:webhook_headers) }.to raise_error(KeyError)
    end
  end

  it 'saves only one answer when a private request runs twice' do
    question
    with_modified_env ROTTA_CONVERSATION_AI_WEBHOOK_SECRET: 'test-only-secret' do
      allow(HTTParty).to receive(:post) do |_url, options|
        payload = JSON.parse(options[:body])
        instance_double(HTTParty::Response, success?: true, parsed_response: {
                          'answer' => '{"answer":"Resposta vinculada","suggested_reply":"Seu rascunho"}',
                          'request_id' => payload['request_id'], 'copilot_thread_id' => thread.id,
                          'conversation_id' => conversation.display_id, 'account_id' => account.id
                        })
      end
      2.times { job.perform(copilot_thread_id: thread.id, user_id: user.id, request_message_id: question.id, message: question.message['content']) }
      expect(HTTParty).to have_received(:post).once
      expect(thread.copilot_messages.assistant.sole.message).to include(
        'content' => 'Resposta vinculada', 'suggested_reply' => 'Seu rascunho', 'in_reply_to' => question.id
      )
    end
  end

  it 'ignores a job whose user does not own the history' do
    peer = create(:user, account: account, role: :administrator)
    expect(HTTParty).not_to receive(:post)
    job.perform(copilot_thread_id: thread.id, user_id: peer.id, request_message_id: question.id, message: question.message['content'])
    expect(thread.copilot_messages.assistant).to be_empty
  end

  it 'sends specialist prompts through the read-only branch of the authenticated webhook' do
    with_modified_env ROTTA_CONVERSATION_AI_WEBHOOK_SECRET: 'test-only-secret' do
      allow(HTTParty).to receive(:post) do |_url, options|
        payload = JSON.parse(options[:body])
        expect(payload).to include('kind' => 'read_only_specialist', 'system_prompt' => 'Sistema', 'prompt' => 'Pergunta')
        expect(options[:timeout]).to eq(38)
        instance_double(HTTParty::Response, success?: true, parsed_response: {
                          'answer' => 'Resposta', 'provider_status' => 200, 'request_id' => payload['request_id'],
                          'copilot_thread_id' => thread.id, 'conversation_id' => conversation.display_id, 'account_id' => account.id
                        })
      end
      expect(job.send(:specialist_client, thread, conversation).call([{ content: 'Sistema' }, { content: 'Pergunta' }])).to eq('Resposta')
    end
  end

  it 'rejects a response correlated to another conversation' do
    expect do
      job.send(
        :validate_response_metadata!,
        {
          'request_id' => 'same-request', 'copilot_thread_id' => thread.id,
          'conversation_id' => conversation.display_id + 1, 'account_id' => account.id
        },
        request_id: 'same-request',
        copilot_thread: thread,
        conversation: conversation
      )
    end.to raise_error(/vínculo inválido/)
  end
end
