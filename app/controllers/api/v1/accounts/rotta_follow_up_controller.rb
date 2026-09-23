class Api::V1::Accounts::RottaFollowUpController < Api::V1::Accounts::BaseController
  ALLOWED_ACTIONS = %w[list config dispatch_now advance delay cancel remove_label].freeze
  MUTATING_ACTIONS = %w[dispatch_now advance delay cancel].freeze
  MUTABLE_REMOTE_STATUSES = %w[pending queued processing syncing sync_failed failed_send failed_labels].freeze
  FOLLOW_UP_STAGE_KEYS = %w[
    contato-instantaneo primeiro-contato segundo-contato terceiro-contato ultimo-contato
    orcamento-instantaneo orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3
    orcamento-tentativa-4 orcamento-5-dias orcamento-10-dias orcamento-15-dias
  ].freeze
  HISTORICAL_REMOTE_STATUSES = %w[history_only sent_history].freeze
  RECOVERY_ACTIVE_STATUSES = %w[pending queued processing syncing sync_failed sending failed_send failed_labels].freeze
  FIRST_CONTACT_STAGE = 'primeiro-contato'.freeze
  MAX_RECONCILIATION_BATCH = 50

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
    body = reconcile_missing_first_contact_jobs(body) if action == 'list' && body.is_a?(Hash)
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

    response = RottaFollowUp::AdminClient.request({
      action: 'list',
      account_id: Current.account.id
    })
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
    response = RottaFollowUp::AdminClient.request({
      action: 'cancel',
      job_id: job_id,
      conversation_id: conversation_id,
      account_id: Current.account.id
    })
    return if response.success?

    raise "O painel não confirmou o cancelamento da etiqueta (HTTP #{response.status})."
  end

  def scope_list_body(body)
    jobs = Array(body['jobs']).select do |job|
      job['account_id'].to_s == Current.account.id.to_s
    end
    body.merge('jobs' => jobs, 'total' => jobs.length)
  end

  # Chatwoot's labels are authoritative for enrollment. If the first-contact
  # webhook was lost, ask the follow-up worker to idempotently rebuild the job,
  # then fetch the queue again so the board renders the confirmed remote row.
  def reconcile_missing_first_contact_jobs(body)
    jobs = Array(body['jobs'])
    first_contact_titles = Current.account.labels.pluck(:title).select do |title|
      follow_up_label_key(title) == FIRST_CONTACT_STAGE
    end
    return body if first_contact_titles.empty?

    active_jobs = jobs.select { |job| RECOVERY_ACTIVE_STATUSES.include?(job['status'].to_s) }
    errors = body['reconciliation_errors'].is_a?(Hash) ? body['reconciliation_errors'].dup : {}
    candidates = Current.account.conversations
                        .tagged_with(first_contact_titles, any: true)
                        .includes(:contact)
                        .distinct
                        .filter_map do |conversation|
      active_labels = conversation.cached_label_list_array
      active_stages = active_labels.filter_map do |label|
        stage = follow_up_label_key(label)
        stage if FOLLOW_UP_STAGE_KEYS.include?(stage)
      end.uniq
      next unless active_stages.include?(FIRST_CONTACT_STAGE)

      conversation_id = conversation.display_id.to_s
      phone = conversation.contact&.phone_number
      normalized_phone = phone_key(phone)
      if active_stages != [FIRST_CONTACT_STAGE]
        errors[conversation_id] = 'Reconciliação automática pausada: há mais de uma etiqueta de etapa ativa. Confira as etiquetas antes de continuar.'
        next
      end
      if normalized_phone.blank? || !normalized_phone.match?(/\A\d{10,15}\z/)
        errors[conversation_id] = 'Reconciliação automática pausada: o contato não tem um telefone válido para o follow-up.'
        next
      end

      has_operational_job = active_jobs.any? do |job|
        job['conversation_id'].to_s == conversation_id || phone_key(job['phone'] || job['phone_number'] || job['contact_phone']) == normalized_phone
      end
      next if has_operational_job

      cache_key = reconciliation_cache_key(conversation_id)
      cached_result = Rails.cache.read(cache_key)
      if cached_result.present?
        errors[conversation_id] = cached_result == 'in_progress' ?
          'Reconciliação em andamento; aguardando confirmação da fila.' : cached_result
        next
      end

      {
        conversation: conversation,
        cache_key: cache_key,
        payload: {
          'conversation_id' => conversation_id,
          'account_id' => Current.account.id.to_s,
          'phone' => phone.to_s,
          'customer_name' => conversation.contact&.name.to_s,
          'stage_label' => FIRST_CONTACT_STAGE,
          'active_labels' => [FIRST_CONTACT_STAGE],
          'source_updated_at' => conversation.updated_at.iso8601(6)
        }
      }
    end

    return body.merge('reconciliation_errors' => errors) if candidates.empty?

    batch = candidates.first(MAX_RECONCILIATION_BATCH)
    batch.each { |candidate| Rails.cache.write(candidate[:cache_key], 'in_progress', expires_in: 30.seconds) }
    reconciliation_error = nil
    begin
      reconciliation = RottaFollowUp::AdminClient.request({
        action: 'reconcile',
        account_id: Current.account.id,
        conversations: batch.map { |candidate| candidate[:payload] }
      })
      unless reconciliation.success?
        reconciliation_error = admin_response_error(reconciliation)
      else
        rejected = Array(reconciliation.body['rejected']).find do |item|
          batch.any? { |candidate| candidate[:payload]['conversation_id'] == item['conversation_id'].to_s }
        end
        reconciliation_error = rejected['error'].to_s.truncate(240) if rejected
      end
    rescue RottaFollowUp::AdminClient::Error => e
      reconciliation_error = e.message
    rescue StandardError => e
      Rails.logger.error("[RottaFollowUp] reconciliation #{e.class}: #{e.message}")
      reconciliation_error = 'Falha inesperada ao reconciliar a etiqueta com a fila.'
    end

    refreshed_body = body
    begin
      refreshed = RottaFollowUp::AdminClient.request({ action: 'list', account_id: Current.account.id })
      if refreshed.success? && refreshed.body.is_a?(Hash)
        refreshed_body = scope_list_body(refreshed.body)
      else
        reconciliation_error ||= "A fila não confirmou a atualização (HTTP #{refreshed.status})."
      end
    rescue RottaFollowUp::AdminClient::Error => e
      reconciliation_error ||= "Não foi possível confirmar a reconciliação: #{e.message}"
    end

    refreshed_jobs = Array(refreshed_body['jobs'])
    batch.each do |candidate|
      conversation_id = candidate[:payload]['conversation_id']
      recovered = refreshed_jobs.any? do |job|
        job['conversation_id'].to_s == conversation_id &&
          follow_up_label_key(job['current_label'].presence || job['source_label']) == FIRST_CONTACT_STAGE &&
          RECOVERY_ACTIVE_STATUSES.include?(job['status'].to_s)
      end
      if recovered
        Rails.cache.delete(candidate[:cache_key])
        errors.delete(conversation_id)
      else
        message = reconciliation_error ||
                  'A fila recebeu a verificação, mas não confirmou a inscrição de primeiro contato. Confira possíveis jobs anteriores ou conflito de telefone.'
        errors[conversation_id] = message
        Rails.cache.write(candidate[:cache_key], message, expires_in: 20.seconds)
      end
    end

    refreshed_body.merge('reconciliation_errors' => errors)
  end

  def reconciliation_cache_key(conversation_id)
    "rotta_follow_up:first_contact_reconcile:#{Current.account.id}:#{conversation_id}"
  end

  def admin_response_error(response)
    body = response.body.is_a?(Hash) ? response.body : {}
    message = body['error'].presence || body['message'].presence || body['detail'].presence
    return message.to_s.truncate(240) if message

    "O painel de follow-up recusou a reconciliação (HTTP #{response.status})."
  end

  def follow_up_label_key(label)
    label.to_s.parameterize.sub(/\A\d+-/, '')
  end

  def phone_key(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.presence
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
    # A remote operational job is authoritative for the conversation. Chatwoot
    # can briefly retain the previous stage label while the label webhook and
    # the worker reconcile, so generating a fallback for every active label
    # would create a second, false card in the board.
    operational_conversation_ids = jobs.reject do |job|
      HISTORICAL_REMOTE_STATUSES.include?(job['status'].to_s)
    end.filter_map { |job| job['conversation_id'].presence&.to_s }.to_set
    operational_phone_keys = jobs.reject do |job|
      HISTORICAL_REMOTE_STATUSES.include?(job['status'].to_s)
    end.filter_map do |job|
      phone_key(job['phone'] || job['phone_number'] || job['contact_phone'])
    end.to_set

    fallback_jobs = Current.account.conversations
                                  .tagged_with(label_titles, any: true)
                                  .includes(:contact)
                                  .distinct
                                  .flat_map do |conversation|
      next [] if operational_conversation_ids.include?(conversation.display_id.to_s)
      next [] if operational_phone_keys.include?(phone_key(conversation.contact&.phone_number))

      # `tagged_with` confirms the database relation; the maintained cache
      # avoids one tag query per conversation on the five-second refresh.
      active_labels = conversation.cached_label_list_array
      active_stage = active_labels.filter_map do |label|
        stage = follow_up_label_key(label)
        next unless FOLLOW_UP_STAGE_KEYS.include?(stage)
        next if existing_keys.include?("#{conversation.display_id}:#{stage}")

        stage
      end.first
      next [] unless active_stage

      # A conversation must occupy one current stage. If an old label is
      # still present while the webhook catches up, keep a single explicit
      # reconciliation row instead of multiplying ghost cards.
      error_message = body.dig('reconciliation_errors', conversation.display_id.to_s)
      [chatwoot_label_fallback(conversation, active_stage, active_labels, error_message: error_message)]
    end

    all_jobs = jobs + fallback_jobs
    body.merge('jobs' => all_jobs, 'total' => all_jobs.length)
  end

  def chatwoot_label_fallback(conversation, stage, active_labels, error_message: nil)
    fallback = {
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
    fallback['error_message'] = error_message if error_message.present?
    fallback
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
