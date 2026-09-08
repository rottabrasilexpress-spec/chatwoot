require 'rails_helper'

RSpec.describe RottaUazapiContactAvatarSyncJob, type: :job do
  it 'uses the dedicated Uazapi queue' do
    expect(described_class.queue_name).to eq('uazapi_sync')
  end

  let(:account) { create(:account) }
  let(:contact) do
    create(
      :contact,
      account: account,
      name: '+5511999999999',
      phone_number: '+5511999999999'
    )
  end

  before do
    stub_const('RottaUazapiContactAvatarSyncJob::BASE_URL', 'https://uazapi.test')
    stub_const('RottaUazapiContactAvatarSyncJob::ACCOUNT_ID', account.id)
    stub_const('ENV', ENV.to_h.merge('ROTTABRASIL_UAZAPI_TOKEN' => 'test-uazapi-token'))
  end

  it 'keeps the event sync marker when the avatar job persists its own attributes' do
    stub_request(:post, 'https://uazapi.test/chat/details')
      .with { |request| JSON.parse(request.body)['number'] == '5511999999999' }
      .to_return(
        status: 200,
        body: {
          name: 'Contato atualizado',
          image: 'https://cdn.uazapi.test/avatar.jpg'
        }.to_json
      )

    allow(Avatar::AvatarFromUrlJob).to receive(:perform_now) do |avatarable, _url|
      avatarable.update_columns(
        additional_attributes: avatarable.additional_attributes.merge(
          'last_avatar_sync_at' => Time.current.iso8601,
          'avatar_url_hash' => 'test-hash'
        )
      )
    end

    described_class.perform_now(account.id, contact.id)

    attributes = contact.reload.additional_attributes
    expect(attributes['rotta_uazapi_avatar_sync_at']).to be_present
    expect(attributes['rotta_uazapi_avatar_sync_status']).to eq('found')
    expect(contact.name).to eq('Contato atualizado')
    expect(attributes['rotta_uazapi_profile_name']).to eq('Contato atualizado')
  end

  it 'does not replace a manually named contact with the provider profile name' do
    contact.update!(name: 'Cliente VIP')

    stub_request(:post, 'https://uazapi.test/chat/details')
      .to_return(status: 200, body: { name: 'Nome do WhatsApp' }.to_json)

    described_class.perform_now(account.id, contact.id)

    expect(contact.reload.name).to eq('Cliente VIP')
    expect(contact.reload.additional_attributes['rotta_uazapi_profile_name']).to be_nil
  end
end
