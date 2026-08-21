class Api::V1::Accounts::RottaFollowUpController < Api::V1::Accounts::BaseController
  ADMIN_URL = 'https://saas.via-cargo.com/webhook/rotta-chatwoot-followup-admin-v1'.freeze
  ALLOWED_ACTIONS = %w[list dispatch_now advance delay cancel].freeze

  def proxy
    payload = params.permit(:action, :job_id, :hours).to_h.stringify_keys
    action = payload['action'].to_s

    unless ALLOWED_ACTIONS.include?(action)
      return render json: { ok: false, error: 'Ação de follow-up inválida.' }, status: :unprocessable_entity
    end

    response = HTTParty.post(
      ADMIN_URL,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: payload.to_json,
      timeout: 20
    )

    body = JSON.parse(response.body)
    render json: body, status: response.code.to_i
  rescue JSON::ParserError
    render json: { ok: false, error: 'A resposta do painel de follow-up não era JSON válido.' }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[RottaFollowUp] #{e.class}: #{e.message}")
    render json: { ok: false, error: 'Não foi possível comunicar com o painel de follow-up.' }, status: :bad_gateway
  end
end
