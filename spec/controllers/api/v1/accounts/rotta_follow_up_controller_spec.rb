require 'rails_helper'

RSpec.describe 'Rotta Follow-up API', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/rotta_follow_up" }

  describe 'POST list' do
    it 'returns the conversation labels as active_labels for reconciliation' do
      upstream_body = {
        jobs: [
          {
            'job_id' => 'job-1',
            'conversation_id' => conversation.display_id.to_s,
            'current_label' => 'kelvin',
            'status' => 'sent_history'
          }
        ]
      }
      upstream_response = instance_double(
        HTTParty::Response,
        body: upstream_body.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      allow_any_instance_of(Conversation).to receive(:label_list).and_return(['Kelvin'])

      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['jobs'].first['active_labels']).to eq(['Kelvin'])
    end
  end
end
