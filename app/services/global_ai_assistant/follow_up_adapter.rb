class GlobalAiAssistant::FollowUpAdapter
  OPERATIONS = %w[dispatch_now advance delay cancel remove_label].freeze

  def self.list
    response = RottaFollowUp::AdminClient.request(action: 'list')
    return response.body if response.success? && response.body.is_a?(Hash)

    { 'available' => false }
  rescue RottaFollowUp::AdminClient::Error
    { 'available' => false }
  end

  def initialize(account:, conversation:, operation:, job_id: nil, hours: nil, label: nil)
    @account = account
    @conversation = conversation
    @operation = operation.to_s
    @job_id = job_id.to_s.strip
    @hours = hours
    @label = label.to_s.strip
  end

  def call
    validate!

    return { 'ok' => true, 'cancelled' => false } if @operation == 'remove_label' && (@job_id.blank? || @job_id.start_with?('pending:'))

    response = RottaFollowUp::AdminClient.request(
      action: @operation == 'remove_label' ? 'cancel' : @operation,
      job_id: @job_id,
      hours: normalised_hours,
      conversation_id: @conversation.display_id
    )
    return response.body if response.success?

    upstream_error = response.body['error'] if response.body.is_a?(Hash)
    raise ArgumentError, upstream_error.presence || "O painel de follow-up recusou a operação (HTTP #{response.status})."

  end

  private

  def validate!
    raise ArgumentError, 'Operação de follow-up inválida.' unless OPERATIONS.include?(@operation)
    raise ArgumentError, 'Job de follow-up é obrigatório.' if @operation != 'remove_label' && (@job_id.blank? || @job_id.start_with?('pending:'))
    raise ArgumentError, 'Etiqueta de follow-up é obrigatória.' if @operation == 'remove_label' && @label.blank?
    raise ArgumentError, 'Prazo em horas é obrigatório para esta operação.' if %w[advance delay].include?(@operation) && normalised_hours.blank?
  end

  def normalised_hours
    return if @hours.blank?

    value = Float(@hours)
    raise ArgumentError, 'Prazo de follow-up inválido.' unless value.positive? && value <= 24 * 365

    value == value.to_i ? value.to_i : value
  rescue ArgumentError, TypeError
    raise ArgumentError, 'Prazo de follow-up inválido.'
  end
end
