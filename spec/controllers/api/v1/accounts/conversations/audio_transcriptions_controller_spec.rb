require 'rails_helper'

RSpec.describe 'Conversation audio transcription API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:upload) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('public/audio/widget/ding.mp3'),
      'audio/mpeg'
    )
  end
  let(:path) do
    "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/audio_transcription"
  end

  it 'requires an authenticated agent' do
    post path, params: { audio: upload }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns text without creating a Chatwoot message' do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
    service = instance_double(Messages::DictationTranscriptionService) # rubocop:disable RSpec/VerifiedDoubles
    allow(Messages::DictationTranscriptionService).to receive(:new).and_return(service)
    allow(service).to receive(:perform).and_return(success: true, text: 'Texto ditado')

    expect do
      post path, params: { audio: upload }, headers: agent.create_new_auth_token
    end.not_to change(Message, :count)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('text' => 'Texto ditado')
  end
end
