require 'rails_helper'

RSpec.describe Api::V1::Accounts::CalculatorController, type: :controller do
  let(:account) { create(:account, settings: { 'rotta_calculator_shared' => false, 'rotta_calculator_owner_id' => owner.id }) }
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    Current.account = account
    Current.user = current_user
  end

  after do
    Current.reset
  end

  context 'when the signed-in user is the configured owner' do
    let(:current_user) { owner }

    it 'allows the calculation' do
      controller.send(:authorize_calculator_access!)

      expect(response).not_to be_committed
    end
  end

  context 'when another agent is signed in' do
    let(:current_user) { other_user }

    it 'does not expose the calculator' do
      controller.send(:authorize_calculator_access!)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to include('responsável')
    end

    it 'halts before running the calculation and avoids a double render' do
      expect(RottaCalculator::CalculateService).not_to receive(:new)

      post :calculate, params: { calculator: {} }

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to include('responsável')
    end
  end
end
