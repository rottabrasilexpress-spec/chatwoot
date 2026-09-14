require 'rails_helper'

RSpec.describe GlobalAiAssistant::FollowUpAdapter do
  let(:account) { instance_double(Account) }
  let(:conversation) { instance_double(Conversation, display_id: '2165') }

  describe '#call' do
    it 'delegates the confirmed operation to the shared follow-up client' do
      response = RottaFollowUp::AdminClient::Response.new(
        status: 200,
        body: { 'ok' => true, 'job_id' => 'job-1' }
      )
      expect(RottaFollowUp::AdminClient).to receive(:request).with(
        action: 'delay',
        job_id: 'job-1',
        hours: 48,
        conversation_id: '2165'
      ).and_return(response)

      result = described_class.new(
        account: account,
        conversation: conversation,
        operation: 'delay',
        job_id: 'job-1',
        hours: 48
      ).call

      expect(result).to include('ok' => true)
    end

    it 'rejects pending jobs because they do not identify a remote follow-up' do
      expect do
        described_class.new(
          account: account,
          conversation: conversation,
          operation: 'cancel',
          job_id: 'pending:2165:kelvin'
        ).call
      end.to raise_error(ArgumentError, /Job de follow-up é obrigatório/)
    end

    it 'rejects invalid delay values before contacting the upstream panel' do
      expect(RottaFollowUp::AdminClient).not_to receive(:request)

      expect do
        described_class.new(
          account: account,
          conversation: conversation,
          operation: 'advance',
          job_id: 'job-1',
          hours: 0
        ).call
      end.to raise_error(ArgumentError, /Prazo de follow-up inválido/)
    end
  end
end
