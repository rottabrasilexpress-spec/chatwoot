class Api::V1::Accounts::RottaFollowUpController < Api::V1::Accounts::BaseController
  ALLOWED_ACTIONS = %w[list config dispatch_now advance delay cancel remove_label].freeze
  MUTATING_ACTIONS = %w[dispatch_now advance delay cancel].freeze
  MUTABLE_REMOTE_STATUSES = %w[pending queued processing syncing sync_failed failed_send failed_labels].freeze
  FOLLOW_UP_STAGE_KEYS = %w[
    contato-instantaneo primeiro-contato segundo-contato terceiro-contato ultimo-contato
    orcamento-instantaneo orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3
    orcamento-tentativa-4 orcamento-5-dias orcamento-10-dias orcamento-15-dias
  ].freeze

  def proxy
    payload = JSON.parse(request.raw_post.presence || '{}').slice(
      'action', 'job_id', 'hours', 'conversation_id', 'label', 'config'
    )
    action = payload['action'].to_s

    unless ALLOWED_ACTIONS.include?(action)
      return render json: { ok: false, error: 'Ação de follow-up inválida.' }, status: :unprocessable_entity
    end

    payload['account_id'] = Current.account.id

    if action == 'remove_label'
      return remove_label(payload)
    end

    if MUTATING_ACTIONS.include?(action)
      return unless authorize_remote_job(payload)
    end

    response = RottaFollowUp::AdminClient.request(
      payload.slice('action', 'job_id', 'hours', 'conversation_id', 'account_id', 'config')
    )
    body = response.body
    body = scope_list_body(body) if action == 'list' && body.is_a?(Hash)
    body = add_delivery_evidence(body) if action == 'list' && body.is_a?(Hash)
    body = add_chatwoot_label_fallbacks(body) if action == 'list' && body.is_a?(Hash)
    render json: body, status: response.status
  rescue RottaFollowUp::AdminClient::Error => e
    Rails.logger.error("[RottaFollowUp] #{e.class}: #{e.message}")
    render json: { ok: false, error: e.message }, status: :bad_gateway
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

    if remote_job_id?(payload['job_id'])
      remote_job = authorize_remote_job(payload)
      return unless remote_job

      cancel_remote_job!(payload['job_id'], conversation_id: conversation_id) if mutable_remote_job?(remote_job)
    end

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

  def authorize_remote_job(payload)
    job_id = payload['job_id'].to_s.strip
    conversation_id = payload['conversation_id'].to_s.strip
    if job_id.blank? || conversation_id.blank?
      render json: { ok: false, error: 'Job e conversa são obrigatórios.' }, status: :unprocessable_entity
      return nil
    end

    response = RottaFollowUp::AdminClient.request(
      action: 'list',
      account_id: Current.account.id
    )
    remote_job = Array(response.body['jobs']).find do |job|
      job['job_id'].to_s == job_id &&
        job['account_id'].to_s == Current.account.id.to_s &&
        job['conversation_id'].to_s == conversation_id
    end

    unless remote_job
      render json: { ok: false, error: 'Job de follow-up não pertence a esta conta e conversa.' }, status: :not_found
      return nil
    end

    unless mutable_remote_job?(remote_job)
      render json: { ok: false, error: 'Este job de follow-up não está ativo para alteração.' }, status: :unprocessable_entity
      return nil
    end

    remote_job
  end

  def mutable_remote_job?(job)
    MUTABLE_REMOTE_STATUSES.include?(job['status'].to_s)
  end

  def cancel_remote_job!(job_id, conversation_id:)
    response = RottaFollowUp::AdminClient.request(
      action: 'cancel',
      job_id: job_id,
      conversation_id: conversation_id,
      account_id: Current.account.id
    )
    return if response.success?

    raise "O painel não confirmou o cancelamento da etiqueta (HTTP #{response.status})."
  end

  def scope_list_body(body)
    jobs = Array(body['jobs']).select do |job|
      job['account_id'].to_s == Current.account.id.to_s
    end
    body.merge('jobs' => jobs, 'total' => jobs.length)
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

  # The external worker is the scheduling source of truth, but Chatwoot labels
  # are the operator's source of truth. If an old/lost webhook leaves a label
  # without a remote job, keep the conversation visible as a reconciliation
  # warning instead of silently showing an empty board. The fallback cannot
  # dispatch; operators may safely remove the label and a later webhook can
  # replace it with a real remote job.
  def add_chatwoot_label_fallbacks(body)
    jobs = Array(body['jobs'])
    label_titles = Current.account.labels.pluck(:title).select do |title|
      FOLLOW_UP_STAGE_KEYS.include?(follow_up_label_key(title))
    end
    return body if label_titles.empty?

    existing_keys = jobs.to_set do |job|
      stage = follow_up_label_key(job['current_label'].presence || job['source_label'])
      "#{job['conversation_id']}:#{stage}"
    end

    fallback_jobs = Current.account.conversations
                                  .tagged_with(label_titles, any: true)
                                  .includes(:contact)
                                  .distinct
                                  .flat_map do |conversation|
      # `tagged_with` confirms the database relation; the maintained cache
      # avoids one tag query per conversation on the five-second refresh.
      active_labels = conversation.cached_label_list_array
      active_labels.filter_map do |label|
        stage = follow_up_label_key(label)
        next unless FOLLOW_UP_STAGE_KEYS.include?(stage)
        next if existing_keys.include?("#{conversation.display_id}:#{stage}")

        chatwoot_label_fallback(conversation, stage, active_labels)
      end
    end

    all_jobs = jobs + fallback_jobs
    body.merge('jobs' => all_jobs, 'total' => all_jobs.length)
  end

  def chatwoot_label_fallback(conversation, stage, active_labels)
    {
      'job_id' => "pending:#{conversation.display_id}:#{stage}",
      'conversation_id' => conversation.display_id.to_s,
      'account_id' => Current.account.id.to_s,
      'customer_name' => conversation.contact&.name,
      'phone' => conversation.contact&.phone_number,
      'source_label' => stage,
      'current_label' => stage,
      'status' => 'sync_failed',
      'pending_enrollment' => true,
      'active_labels' => active_labels,
      'reconciliation_source' => 'chatwoot_label'
    }
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
