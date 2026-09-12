require 'rails_helper'

RSpec.describe Messages::UazapiCustomerDeletionDetector do
  it 'recognizes explicit customer deletion events' do
    expect(described_class.call(payload: {}, event: 'message_deleted')).to be(true)
  end

  it 'recognizes nested camel-case delete markers in generic message events' do
    payload = { 'data' => { 'deletedForEveryone' => true, 'fromMe' => false } }

    expect(described_class.call(payload: payload, event: 'messages_update')).to be(true)
  end

  it 'does not classify an ordinary customer message as deleted' do
    payload = { 'data' => { 'text' => 'Olá', 'fromMe' => false } }

    expect(described_class.call(payload: payload, event: 'messages')).to be(false)
  end

  it 'does not classify a provider deletion marker on an unrelated event' do
    payload = { 'data' => { 'deleted' => true } }

    expect(described_class.call(payload: payload, event: 'history')).to be(false)
  end
end
