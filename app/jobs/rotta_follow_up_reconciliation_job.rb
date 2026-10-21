# frozen_string_literal: true

class RottaFollowUpReconciliationJob < ApplicationJob
  queue_as :low
  STAGE_KEYS = (RottaFollowUp::ListPage::CONTACT + RottaFollowUp::ListPage::BUDGET +
                %w[contato-instantaneo orcamento-instantaneo]).freeze

  def perform(account_id, candidates)
    # Re-read labels before calling n8n: removing/changing a stage while this
    # job waits must not resurrect the old follow-up. n8n also verifies them.
    account = Account.find(account_id)
    eligible = Array(candidates).select do |candidate|
      conversation = account.conversations.find_by(display_id: candidate['conversation_id'])
      stages = conversation&.labels_for_display.to_a.map { |label| label.to_s.parameterize.sub(/\A\d+-/, '') }
      (stages & STAGE_KEYS) == [candidate['stage_label']]
    end
    return if eligible.empty?

    response = RottaFollowUp::AdminClient.request(action: 'reconcile', account_id: account_id, conversations: eligible)
    raise RottaFollowUp::AdminClient::RequestError, response_error(response) unless response.success?

    refreshed = RottaFollowUp::AdminClient.request(action: 'list', account_id: account_id, operational_only: true)
    raise RottaFollowUp::AdminClient::RequestError, response_error(refreshed) unless refreshed.success?

    jobs = Array(refreshed.body['jobs'])
    eligible.each do |candidate|
      recovered = jobs.any? do |job|
        job['account_id'].to_s == account_id.to_s &&
          job['conversation_id'].to_s == candidate['conversation_id'].to_s &&
          (job['current_label'].presence || job['source_label']).to_s.parameterize.sub(/\A\d+-/, '') == candidate['stage_label'] &&
          %w[pending queued processing syncing sync_failed sending failed_send failed_labels].include?(job['status'])
      end
      next if recovered

      rejection = Array(response.body['rejected']).find { |item| item['conversation_id'].to_s == candidate['conversation_id'].to_s }
      message = rejection&.fetch('error', nil).presence ||
                'A fila recebeu a verificação, mas não confirmou a inscrição desta etapa. Confira possíveis jobs anteriores ou conflito de telefone.'
      Redis::Alfred.set(cache_key(account_id, candidate), message.to_s.truncate(240), ex: 20)
    end
  rescue RottaFollowUp::AdminClient::Error => e
    Array(candidates).each { |candidate| Redis::Alfred.set(cache_key(account_id, candidate), e.message, ex: 20) }
    Rails.logger.warn("[RottaFollowUp] background reconciliation failed class=#{e.class.name}")
  ensure
    Array(candidates).each do |candidate|
      Redis::Alfred.delete_if_equals(cache_key(account_id, candidate), 'in_progress')
    end
  end

  private

  def cache_key(account_id, candidate)
    "rotta_follow_up:stage_reconcile:#{account_id}:#{candidate['conversation_id']}:#{candidate['stage_label']}"
  end

  def response_error(response)
    body = response.body.is_a?(Hash) ? response.body : {}
    message = body['error'].presence || body['message'].presence || body['detail'].presence
    message&.to_s&.truncate(240) || "O painel de follow-up recusou a reconciliação (HTTP #{response.status})."
  end
end
