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

    it 'keeps an active Chatwoot follow-up label visible when the remote job is missing' do
      create(:label, account: account, title: 'primeiro-contato')
      conversation.update_labels(['primeiro-contato'])
      upstream_response = instance_double(
        HTTParty::Response,
        body: { jobs: [] }.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      fallback = response.parsed_body['jobs'].sole
      expect(fallback).to include(
        'job_id' => "pending:#{conversation.display_id}:primeiro-contato",
        'conversation_id' => conversation.display_id.to_s,
        'current_label' => 'primeiro-contato',
        'status' => 'sync_failed',
        'pending_enrollment' => true,
        'reconciliation_source' => 'chatwoot_label'
      )
      expect(response.parsed_body['total']).to eq(1)
    end

    it 'does not duplicate a remote job that already matches the active Chatwoot label' do
      create(:label, account: account, title: 'primeiro-contato')
      conversation.update_labels(['primeiro-contato'])
      upstream_response = instance_double(
        HTTParty::Response,
        body: {
          jobs: [
            {
              'job_id' => 'job-current',
              'account_id' => account.id.to_s,
              'conversation_id' => conversation.display_id.to_s,
              'current_label' => 'primeiro-contato',
              'status' => 'pending'
            }
          ]
        }.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      expect(response.parsed_body['jobs'].map { |job| job['job_id'] }).to eq(['job-current'])
      expect(response.parsed_body['total']).to eq(1)
    end

    it 'does not create a fallback for a stale second label when the conversation has an operational remote job' do
      create(:label, account: account, title: 'primeiro-contato')
      create(:label, account: account, title: 'segundo-contato')
      conversation.contact.update!(phone_number: '5511965927865')
      conversation.update_labels(%w[primeiro-contato segundo-contato])
      upstream_response = instance_double(
        HTTParty::Response,
        body: {
          jobs: [
            {
              'job_id' => 'job-current',
              'account_id' => account.id.to_s,
              'conversation_id' => '2143',
              'phone' => '+5511965927865',
              'current_label' => 'primeiro-contato',
              'status' => 'pending'
            }
          ]
        }.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      expect(response.parsed_body['jobs'].map { |job| job['job_id'] }).to eq(['job-current'])
      expect(response.parsed_body['total']).to eq(1)
    end

    it 'keeps one reconciliation row when multiple stale follow-up labels exist without a remote job' do
      create(:label, account: account, title: 'primeiro-contato')
      create(:label, account: account, title: 'segundo-contato')
      conversation.update_labels(%w[primeiro-contato segundo-contato])
      upstream_response = instance_double(
        HTTParty::Response,
        body: { jobs: [] }.to_json,
        code: 200
      )

      allow(HTTParty).to receive(:post).and_return(upstream_response)
      post endpoint,
           headers: user.create_new_auth_token,
           params: { action: 'list' }.to_json,
           as: :json

      expect(response.parsed_body['jobs'].size).to eq(1)
      expect(response.parsed_body['jobs'].first['pending_enrollment']).to be(true)
      expect(response.parsed_body['total']).to eq(1)
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
