require 'rails_helper'

RSpec.describe RottaAiStatus::Client do
  let(:connection) { instance_double(Faraday::Connection) }
  let(:url) { 'https://saas.via-cargo.com/webhook/rotta/ai-status-read-v1' }
  let(:secret) { 'a' * 48 }

  describe '#statuses_for' do
    it 'signs a deterministic, sorted batch and accepts only known states' do
      jids = ['5511987654321@s.whatsapp.net', '5511991234567@s.whatsapp.net']
      body = JSON.generate(instance: 'rotta', remote_jids: jids.sort)
      timestamp = Time.current.to_i.to_s
      canonical = [timestamp, 'rotta', *jids.sort].join("\n")
      signature = OpenSSL::HMAC.hexdigest('SHA256', secret, canonical)
      response = instance_double(Faraday::Response, status: 200, success?: true, body: {
        statuses: [
          { remote_jid: jids.first, state: 'blocked' },
          { remote_jid: jids.last, state: 'incorrect' }
        ].to_json
      })
      client = described_class.new(url: url, secret: secret, connection: connection)

      expect(connection).to receive(:post).with(
        url,
        body,
        hash_including(
          'X-Rotta-Status-Timestamp' => timestamp,
          'X-Rotta-Status-Signature' => "sha256=#{signature}"
        )
      ).and_return(response)

      expect(client.statuses_for(jids.reverse)).to eq(jids.first => 'blocked')
    end

    it 'fails closed when the endpoint configuration is missing' do
      client = described_class.new(url: nil, secret: nil, connection: connection)

      expect(connection).not_to receive(:post)
      expect(client.statuses_for(['5511991234567@s.whatsapp.net'])).to eq({})
    end

    it 'fails closed when n8n is unavailable' do
      client = described_class.new(url: url, secret: secret, connection: connection)

      allow(connection).to receive(:post).and_raise(Faraday::TimeoutError)
      expect(client.statuses_for(['5511991234567@s.whatsapp.net'])).to eq({})
    end

    it 'ignores malformed status items without failing the endpoint' do
      response = instance_double(Faraday::Response, status: 200, success?: true, body: {
        statuses: [
          nil,
          { remote_jid: nil, state: 'active' },
          { remote_jid: '5511991234567@s.whatsapp.net', state: 'blocked' }
        ].to_json
      })
      client = described_class.new(url: url, secret: secret, connection: connection)

      allow(connection).to receive(:post).and_return(response)

      expect(client.statuses_for(['5511991234567@s.whatsapp.net'])).to eq(
        '5511991234567@s.whatsapp.net' => 'blocked'
      )
    end

    it 'returns no statuses when the response JSON is null' do
      response = instance_double(Faraday::Response, status: 200, success?: true, body: 'null')
      client = described_class.new(url: url, secret: secret, connection: connection)

      allow(connection).to receive(:post).and_return(response)

      expect(client.statuses_for(['5511991234567@s.whatsapp.net'])).to eq({})
    end
  end
end
