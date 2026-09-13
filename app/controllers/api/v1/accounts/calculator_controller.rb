class Api::V1::Accounts::CalculatorController < Api::V1::Accounts::BaseController
  def calculate
    return unless authorize_calculator_access!

    calculation = ::RottaCalculator::CalculateService.new(calculator_params).call
    render json: calculation, status: :ok
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ::RottaCalculator::ConfigurationError => e
    Rails.logger.error("[RottaCalculator] configuration error: #{e.message}")
    render json: { error: 'A calculadora ainda não está configurada para este ambiente.' }, status: :service_unavailable
  rescue ::RottaCalculator::UpstreamError => e
    Rails.logger.error("[RottaCalculator] upstream error: #{e.message}")
    render json: { error: 'Não foi possível consultar uma das integrações da calculadora.' }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[RottaCalculator] #{e.class}: #{e.message}")
    render json: { error: 'Não foi possível concluir o cálculo agora.' }, status: :bad_gateway
  end

  private

  def authorize_calculator_access!
    settings = Current.account.settings || {}
    shared = ActiveModel::Type::Boolean.new.cast(settings['rotta_calculator_shared'])
    owner_id = settings['rotta_calculator_owner_id'].presence
    return true if shared || (owner_id.present? && owner_id.to_i == Current.user.id)

    render json: { error: 'A Calculadora está disponível somente para o agente responsável.' }, status: :forbidden
    false
  end

  def calculator_params
      params.require(:calculator).permit(
        :reading_text,
        freight: %i[client_name date origin destination],
        services: %i[label selected],
        inventory: %i[text item_count volume_m3],
        pricing: [
          :selected_card_id, :margin_percent, :adjustment_per_km, :adjustment_step, :route_mode,
          :helper_unit, :assembler_unit, :materials_selected, :materials_total,
          :special_fee,
          helpers: %i[origin destination],
          assembly: %i[origin_disassembly destination_assembly]
        ]
      ).to_h.deep_stringify_keys
  end
end
