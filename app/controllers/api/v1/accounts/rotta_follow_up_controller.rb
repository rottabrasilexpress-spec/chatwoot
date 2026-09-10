class Api::V1::Accounts::RottaFollowUpController < Api::V1::Accounts::BaseController
  ADMIN_URL = 'https://saas.via-cargo.com/webhook/rotta-chatwoot-followup-admin-v1'.freeze
  ALLOWED_ACTIONS = %w[list config dispatch_now advance delay cancel remove_label].freeze

  def proxy
    payload = JSON.parse(request.raw_post.presence || '{}').slice(
      'action', 'job_id', 'hours', 'conversation_id', 'label', 'config'
    )
    action = payload['action'].to_s

    unless ALLOWED_ACTIONS.include?(action)
      return render json: { ok: false, error: 'Ação de follow-up inválida.' }, status: :unprocessable_entity
    end

    return remove_label(payload) if action == 'remove_label'

    response = HTTParty.post(
      ADMIN_URL,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: payload.slice('action', 'job_id', 'hours', 'config').to_json,
      timeout: 20
    )

    body = JSON.parse(response.body)
    body = add_delivery_evidence(body) if action == 'list' && body.is_a?(Hash)
    render json: body, status: response.code.to_i
  rescue JSON::ParserError
    render json: { ok: false, error: 'A resposta do painel de follow-up não era JSON válido.' }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[RottaFollowUp] #{e.class}: #{e.message}")
    render json: { ok: false, error: 'Não foi possível comunicar com o painel de follow-up.' }, status: :bad_gateway
  end

  private

  def remove_label(payload)
    conversation_id = payload['conversation_id'].presence
    requested_label = payload['label'].to_s.strip
    if conversation_id.blank? || requested_label.blank?
      return render json: { ok: false, error: 'Conversa e etiqueta são obrigatórias.' }, status: :unprocessable_entity
    end

    conversation = Current.account.conversations.find_by(display_id: conversation_id)
    return render json: { ok: false, error: 'Conversa não encontrada.' }, status: :not_found unless conversation

    cancel_remote_job!(payload['job_id']) if remote_job_id?(payload['job_id'])

    current_labels = conversation.label_list
    updated_labels = current_labels.reject do |label|
      follow_up_label_key(label) == follow_up_label_key(requested_label)
    end
    removed = updated_labels.length != current_labels.length
    conversation.update_labels(updated_labels) if removed

    render json: {
      ok: true,
      removed: removed,
      cancelled: remote_job_id?(payload['job_id']),
      conversation_id: conversation.display_id,
      labels: conversation.label_list
    }
  end

  def remote_job_id?(job_id)
    job_id.present? && !job_id.to_s.start_with?('pending:')
  end

  def cancel_remote_job!(job_id)
    response = HTTParty.post(
      ADMIN_URL,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: { action: 'cancel', job_id: job_id }.to_json,
      timeout: 20
    )
    body = JSON.parse(response.body)
    return if response.code.to_i.between?(200, 299) && body['ok'] != false

    raise "O painel não confirmou o cancelamento da etiqueta (HTTP #{response.code})."
  end

  def follow_up_label_key(label)
    label.to_s.parameterize.sub(/\A\d+-/, '')
  end

  # The worker can create the Chatwoot message before its Uazapi ACK arrives.
  # Keep the n8n status untouched, but expose the local message as auditable
  # evidence so the UI never presents a completed local send as an opaque
  # "processing" state.
  def add_delivery_evidence(body)
    jobs = body['jobs']
    return body unless jobs.is_a?(Array)

    conversation_ids = jobs.filter_map { |job| job['conversation_id'].presence }.uniq
    conversations = Current.account.conversations.where(display_id: conversation_ids).index_by do |conversation|
      conversation.display_id.to_s
    end

    body['jobs'] = jobs.map do |job|
      conversation = conversations[job['conversation_id'].to_s]
      evidence = find_delivery_evidence(conversation, job) if conversation
      active_labels = conversation ? conversation.label_list : []
      enriched_job = job.merge('active_labels' => active_labels)
      evidence ? enriched_job.merge('delivery_evidence' => evidence) : enriched_job
    end
    body
  end

  def find_delivery_evidence(conversation, job)
    scheduled_at = parse_time(job['scheduled_at'])
    return unless scheduled_at

    # A small recent window is enough to correlate a worker dispatch while
    # avoiding a full historical-message load for every row in the queue.
    message = conversation.messages
                           .where(message_type: Message.message_types[:outgoing], private: false)
                           .where('created_at >= ?', scheduled_at - 5.minutes)
                           .order(created_at: :desc)
                           .limit(20)
                           .find { |candidate| candidate.created_at >= scheduled_at }
    delivery_evidence_for(message) if message
  end

  def delivery_evidence_for(message)
    attributes = message.additional_attributes.is_a?(Hash) ? message.additional_attributes : {}
    content_attributes = message.content_attributes.is_a?(Hash) ? message.content_attributes : {}
    provider_status = attributes['uazapi_status'] || attributes['uazapiStatus'] ||
                      content_attributes['uazapi_status'] || content_attributes['uazapiStatus']

    {
      'message_id' => message.id,
      'created_at' => message.created_at.iso8601,
      'status' => message.status,
      'source_id' => message.source_id,
      'provider_status' => provider_status,
      'content_preview' => message.content.to_s.truncate(160)
    }
  end

  def parse_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
