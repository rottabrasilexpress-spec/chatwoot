require 'rails_helper'

RSpec.describe 'Rotta pickup dates' do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Cliente de teste') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:headers) { agent.create_new_auth_token }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:label_url) { "#{base}/conversations/#{conversation.display_id}/labels" }

  before do
    %w[clientes-fechados finalizados kelvin].each { |title| create(:label, account: account, title: title) }
  end

  it 'rejects a label changeset without a date and preserves existing labels and name' do
    conversation.update_labels(['kelvin'])
    post label_url, params: { add: ['clientes-fechados'], remove: ['kelvin'] }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(conversation.reload.label_list).to eq(['kelvin'])
    expect(contact.reload.name).to eq('Cliente de teste')
  end

  it 'saves and renames once, lists the move, then replaces only the closed label' do
    2.times do
      post label_url, params: { add: %w[clientes-fechados kelvin], pickup: { starts_on: '2026-11-23', ends_on: '2026-11-25' } },
                      headers: headers, as: :json
      expect(response).to have_http_status(:ok)
    end
    expect(contact.reload.name).to eq('Cliente de teste 23/11/2026 até 25/11')
    get "#{base}/rotta_pickups", headers: headers
    expect(response.parsed_body['items'].pluck('id')).to eq([conversation.display_id])
    post "#{base}/rotta_pickups/#{conversation.display_id}/complete",
         params: { starts_on: '2026-11-23', ends_on: '2026-11-25' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(conversation.reload.label_list).to contain_exactly('kelvin', 'finalizados')
    get "#{base}/rotta_pickups", headers: headers
    expect(response.parsed_body['items']).to be_empty
  end
end
