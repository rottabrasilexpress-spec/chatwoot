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

  it 'confirms a day inside the existing window and keeps an independent delivery date' do
    post label_url, params: { add: %w[clientes-fechados kelvin],
                              pickup: { starts_on: '2026-11-23', ends_on: '2026-11-25', delivery_on: '2026-11-28' } },
                    headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    url = "#{base}/rotta_pickups/#{conversation.display_id}"
    original = { starts_on: '2026-11-23', ends_on: '2026-11-25', delivery_on: '2026-11-28', note: nil }
    patch url, params: { expected: original, confirm_window: true, pickup: { starts_on: '2026-11-26' } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    patch url, params: { expected: original, confirm_window: true, pickup: { starts_on: '2026-11-24' } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['pickup']).to include('starts_on' => '2026-11-24', 'ends_on' => nil, 'delivery_on' => '2026-11-28')
    expect(conversation.reload.label_list).to contain_exactly('clientes-fechados', 'kelvin')
    expect(contact.reload.name).to eq('Cliente de teste 24/11/2026')
    patch url, params: { expected: original, pickup: { starts_on: '2026-11-23' } }, headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'acknowledges delivery and pickup separately when both reminders are due' do
    travel_to(Time.utc(2026, 11, 20, 15)) do
      post label_url, params: { add: ['clientes-fechados'],
                                pickup: { starts_on: '2026-11-21', delivery_on: '2026-11-22' } },
                      headers: headers, as: :json
      get "#{base}/rotta_pickups/reminders?include_delivery=true", headers: headers
      expect(response).to have_http_status(:ok)
      reminders = response.parsed_body['items']
      expect(reminders.pluck('reminder_kind')).to contain_exactly('pickup', 'delivery')
      post "#{base}/rotta_pickups/acknowledge",
           params: { day: '2026-11-20', items: reminders.select { |item| item['reminder_kind'] == 'delivery' } },
           headers: headers, as: :json
      get "#{base}/rotta_pickups/reminders?include_delivery=true", headers: headers
      expect(response.parsed_body['items'].pluck('reminder_kind')).to eq(['pickup'])
    end
  end
end
