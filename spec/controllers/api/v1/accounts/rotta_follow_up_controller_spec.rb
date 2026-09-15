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

    it 'scopes upstream jobs to the current account' do
      upstream_body = {
        jobs: [
          {
            'job_id' => 'job-current',
            'account_id' => account.id.to_s,
            'conversation_id' => conversation.display_id.to_s,
            'current_label' => 'kelvin',
            'status' => 'pending'
          },
          {
            'job_id' => 'job-other',
            'account_id' => (account.id + 1).to_s,
            'conversation_id' => '9999',
            'current_label' => 'kelvin',
            'status' => 'pending'
          }
        ]
      }
      upstream_response = instance_double(
        HTTParty::Response,
        body: upstream_body.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['jobs'].map { |job| job['job_id'] }).to eq(['job-current'])
    end
  end

  describe 'mutating actions' do
    let(:remote_job) do
      {
        'job_id' => 'job-1',
        'account_id' => account.id.to_s,
        'conversation_id' => conversation.display_id.to_s,
        'current_label' => 'primeiro-contato',
        'status' => 'pending'
      }
    end

    it 'rejects a job from another account before forwarding a mutation' do
      other_account = create(:account)
      upstream_body = {
        jobs: [remote_job.merge(
          'account_id' => other_account.id.to_s,
          'conversation_id' => 'other-conversation'
        )]
      }
      upstream_response = instance_double(
        HTTParty::Response,
        body: upstream_body.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: {
             action: 'cancel',
             job_id: remote_job['job_id'],
             conversation_id: conversation.display_id
           }.to_json,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to include('não pertence')
      expect(HTTParty).to have_received(:post).once
    end

    it 'requires the remote job to match the local conversation before removing a label' do
      allow(conversation).to receive(:label_list).and_return(['Primeiro contato'])
      allow(conversation).to receive(:update_labels)
      upstream_response = instance_double(
        HTTParty::Response,
        body: { jobs: [remote_job.merge('conversation_id' => 'other-conversation')] }.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: {
             action: 'remove_label',
             job_id: remote_job['job_id'],
             conversation_id: conversation.display_id,
             label: 'primeiro-contato'
           }.to_json,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(conversation).not_to have_received(:update_labels)
      expect(HTTParty).to have_received(:post).once
    end
  end
end
