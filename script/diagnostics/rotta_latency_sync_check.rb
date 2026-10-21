# Execute only in an isolated rails runner, never inside the web process.
# All writes/HTTP/queue operations below are process-local fakes.
# Usage: bundle exec rails runner script/diagnostics/rotta_latency_sync_check.rb
require 'ostruct'
checks = []
check = ->(name, result) { checks << { check: name, pass: !!result }; raise name unless result }
scope_class = Class.new(Array) do
  def tagged_with(*) = self
  def includes(*) = self
  def distinct = self
  def where = self
  def not(display_id:) = self.class.new(reject { |c| Array(display_id).map(&:to_s).include?(c.display_id.to_s) })
  def find_by(display_id:) = find { |c| c.display_id.to_s == display_id.to_s }
end
contact = OpenStruct.new(phone_number: '+5511991262866', name: 'Synthetic local-only test')
conversation = OpenStruct.new(display_id: 123, labels_for_display: ['primeiro-contato'], contact: contact, updated_at: Time.current)
scope = scope_class.new([conversation])
account = OpenStruct.new(id: 987654, conversations: scope, labels: [OpenStruct.new(title: 'primeiro-contato')])
Current.account = account
Account.define_singleton_method(:find) { |_id| account }
memory = {}
Redis::Alfred.define_singleton_method(:get) { |key| memory[key] }
Redis::Alfred.define_singleton_method(:set) do |key, value, nx: false, ex: false|
  next false if nx && memory.key?(key)
  memory[key] = value
  true
end
Redis::Alfred.define_singleton_method(:delete_if_equals) { |key, value| memory.delete(key) if memory[key] == value }
queued = []
RottaFollowUpReconciliationJob.define_singleton_method(:perform_later) { |*args| queued << args }
calls = []
RottaFollowUp::AdminClient.define_singleton_method(:request) { |payload| calls << payload; raise 'REMOTE_CALL_ON_WEB_PATH' }
controller = Webhooks::UazapiController.new
controller.define_singleton_method(:params) { {} }
%w[messages contacts messages_update].each do |event|
  check.call("body_event_#{event}", controller.send(:extract_event, { 'EventType' => event }) == event)
end
controller.define_singleton_method(:params) { { event: 'MESSAGES/text' } }
check.call('route_suffix_preserved', controller.send(:extract_event, { 'event' => 'contacts' }) == 'messages')
follow_up = Api::V1::Accounts::RottaFollowUpController.new
result = follow_up.send(:reconcile_missing_follow_up_jobs, { 'jobs' => [] })
check.call('read_path_does_not_reconcile_over_http', calls.empty? && queued.size == 1)
check.call('pending_reconciliation_is_visible', result['reconciliation_errors']['123'].include?('andamento'))
follow_up.send(:reconcile_missing_follow_up_jobs, { 'jobs' => [] })
check.call('parallel_reads_do_not_duplicate_job', queued.size == 1)
candidate = queued.first.last.first
conversation.labels_for_display = []
RottaFollowUpReconciliationJob.new.perform(account.id, [candidate])
check.call('removed_stage_is_not_recreated', calls.empty? && memory.empty?)
conversation.labels_for_display = ['primeiro-contato']
cancelled = { 'jobs' => [{ 'status' => 'cancelled', 'error_message' => 'cancelado pelo painel', 'conversation_id' => '123' }] }
follow_up.send(:reconcile_missing_follow_up_jobs, cancelled)
check.call('manual_cancellation_stays_cancelled', queued.size == 1)
conversation.labels_for_display = %w[primeiro-contato segundo-contato]
follow_up.send(:reconcile_missing_follow_up_jobs, { 'jobs' => [] })
check.call('multiple_stages_stay_blocked', queued.size == 1)
RottaFollowUpReconciliationJob.new.perform(account.id, [candidate])
check.call('background_also_rejects_concurrent_stages', calls.empty?)
conversation.labels_for_display = ['primeiro-contato']
reply = RottaFollowUp::AdminClient::Response
RottaFollowUp::AdminClient.define_singleton_method(:request) do |payload|
  calls << payload
  reply.new(status: 200, body: payload[:action] == 'list' ? { 'jobs' => [{
    'account_id' => account.id.to_s, 'conversation_id' => '123', 'current_label' => 'primeiro-contato', 'status' => 'pending'
  }] } : { 'ok' => true })
end
RottaFollowUpReconciliationJob.new.perform(account.id, [candidate])
check.call('background_reconciliation_confirmed', calls.map { |c| c[:action] } == %w[reconcile list] && memory.empty?)
RottaFollowUp::AdminClient.define_singleton_method(:request) do |_payload|
  reply.new(status: 503, body: { 'error' => 'synthetic upstream unavailable' })
end
RottaFollowUpReconciliationJob.new.perform(account.id, [candidate])
check.call('real_error_is_preserved', memory.values.include?('synthetic upstream unavailable'))
memory.clear
history = RottaUazapiHistoryReconciliationJob.new
records = [
  { 'messageid' => 'existing', 'timestamp' => Time.current.to_i },
  { 'messageid' => 'missing', 'timestamp' => Time.current.to_i },
  { 'messageid' => 'existing', 'edited' => 'existing', 'timestamp' => Time.current.to_i }
]
history.define_singleton_method(:uazapi_post) { |*| { 'messages' => records } }
replayed = []
history.define_singleton_method(:replay_message) { |message| replayed << message }
Message.define_singleton_method(:where) do |**options|
  raise 'Unscoped history query' unless options[:account_id] == RottaUazapiHistoryReconciliationJob::ACCOUNT_ID
  Object.new.tap { |relation| relation.define_singleton_method(:pluck) { |*| ['uazapi:existing'] } }
end
history.send(:replay_missing_messages, { 'chatid' => 'synthetic@s.whatsapp.net' }, 1.hour.ago)
check.call('history_skips_persisted_but_preserves_edits', replayed.map { |m| m['messageid'] } == %w[missing existing])
history_http = RottaUazapiHistoryReconciliationJob.new
http_headers = nil
history_http.define_singleton_method(:webhook_uri) { URI('http://rails:3000/synthetic') }
history_http.define_singleton_method(:http_request) do |_uri, _klass, _body, headers|
  http_headers = headers
  Struct.new(:code).new('200')
end
history_http.send(:replay_message, {})
check.call('internal_recovery_bypasses_ssl_redirect_without_disabling_ssl', http_headers['X-Forwarded-Proto'] == 'https')
lock_key = 'rotta:uazapi:history-reconciliation:lock'
history.send(:with_reconciliation_lock) { memory[lock_key] = 'replacement-owner' }
check.call('expired_lock_does_not_delete_new_owner', memory[lock_key] == 'replacement-owner')
puts({ diag: 'ROTTA-ISOLATED-REGRESSION', checks: checks, writes_to_database: 0, messages_sent: 0 }.to_json)
