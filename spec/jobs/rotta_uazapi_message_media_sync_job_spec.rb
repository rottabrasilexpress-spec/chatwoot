require 'rails_helper'

RSpec.describe RottaUazapiMessageMediaSyncJob, type: :job do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, message_type: :incoming) }

  around do |example|
    original_token = ENV.fetch('ROTTABRASIL_UAZAPI_TOKEN', nil)
    ENV['ROTTABRASIL_UAZAPI_TOKEN'] = 'test-uazapi-token'
    example.run
  ensure
    if original_token
      ENV['ROTTABRASIL_UAZAPI_TOKEN'] = original_token
    else
      ENV.delete('ROTTABRASIL_UAZAPI_TOKEN')
    end
  end

  it 'uses the dedicated Uazapi queue' do
    expect(described_class.queue_name).to eq('uazapi_sync')
  end

  it 'downloads and stores provider media returned by message download' do
    provider_id = 'uazapi-media-download-1'
    media_url = 'https://example.com/uazapi-document.pdf'
    stub_request(:post, 'https://transportadoras.uazapi.com/message/download')
      .with(body: hash_including('id' => provider_id))
      .to_return(
        status: 200,
        body: { fileURL: media_url, mimetype: 'application/pdf' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, media_url).to_return(
      status: 200,
      body: '%PDF-test',
      headers: { 'Content-Type' => 'application/pdf' }
    )

    described_class.perform_now(account.id, message.id, provider_id, nil, 'document')

    attachment = message.reload.attachments.first
    expect(attachment).to be_present
    expect(attachment.file_type).to eq('file')
    expect(attachment.file).to be_attached
    expect(attachment.meta['uazapi_message_id']).to eq(provider_id)
  end

  it 'does not create a duplicate attachment when the job is retried' do
    provider_id = 'uazapi-media-duplicate-1'
    media_url = 'https://example.com/uazapi-image.png'
    stub_request(:get, media_url).to_return(
      status: 200,
      body: Rails.root.join('spec/assets/avatar.png').binread,
      headers: { 'Content-Type' => 'image/png' }
    )

    2.times { described_class.perform_now(account.id, message.id, provider_id, media_url, 'image') }

    expect(message.reload.attachments.where("meta ->> 'uazapi_message_id' = ?", provider_id).count).to eq(1)
    expect(a_request(:get, media_url)).to have_been_made.once
  end

  it 'deduplicates a direct media URL when the provider omits its message ID' do
    media_url = 'https://example.com/uazapi-image-without-id.png'
    stub_request(:get, media_url).to_return(
      status: 200,
      body: Rails.root.join('spec/assets/avatar.png').binread,
      headers: { 'Content-Type' => 'image/png' }
    )

    2.times { described_class.perform_now(account.id, message.id, nil, media_url, 'image') }

    expect(message.reload.attachments.count).to eq(1)
    expect(a_request(:get, media_url)).to have_been_made.once
  end

  it 'deduplicates the same URL when a provider ID appears on a later retry' do
    media_url = 'https://example.com/uazapi-image-id-backfill.png'
    stub_request(:get, media_url).to_return(
      status: 200,
      body: Rails.root.join('spec/assets/avatar.png').binread,
      headers: { 'Content-Type' => 'image/png' }
    )

    described_class.perform_now(account.id, message.id, nil, media_url, 'image')
    described_class.perform_now(account.id, message.id, 'uazapi-media-id-backfill-1', media_url, 'image')

    expect(message.reload.attachments.count).to eq(1)
    expect(a_request(:get, media_url)).to have_been_made.once
  end

  it 'deduplicates the same URL when a provider ID disappears on a later retry' do
    media_url = 'https://example.com/uazapi-image-id-loss.png'
    stub_request(:get, media_url).to_return(
      status: 200,
      body: Rails.root.join('spec/assets/avatar.png').binread,
      headers: { 'Content-Type' => 'image/png' }
    )

    described_class.perform_now(account.id, message.id, 'uazapi-media-id-loss-1', media_url, 'image')
    described_class.perform_now(account.id, message.id, nil, media_url, 'image')

    expect(message.reload.attachments.count).to eq(1)
    expect(a_request(:get, media_url)).to have_been_made.once
  end

  it 'raises after a transient provider failure so the queue can retry' do
    provider_id = 'uazapi-media-retry-1'
    stub_request(:post, 'https://transportadoras.uazapi.com/message/download')
      .with(body: hash_including('id' => provider_id))
      .to_return(status: 503, body: '{}', headers: { 'Content-Type' => 'application/json' })

    expect do
      described_class.perform_now(account.id, message.id, provider_id, nil, 'image')
    end.to raise_error(RottaUazapiMessageMediaSyncJob::MediaSyncError)
  end
end
