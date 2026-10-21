const body = $json.body || $json;
const action = String(body.action || 'list');
if (action === 'reconcile') {
  const requested = body.conversations;
  const accountId = Number(body.account_id);
  if (!Number.isSafeInteger(accountId) || accountId <= 0) throw new Error('Conta inválida para reconciliar etiquetas');
  if (!Array.isArray(requested) || requested.length < 1 || requested.length > 50) throw new Error('A reconciliação aceita entre 1 e 50 conversas por lote');
}
const jobId = String(body.job_id || '').replace(/'/g, "''");
const hours = Math.max(-720, Math.min(720, Number(body.hours || 0)));
const q = value => "'" + String(value ?? '').replace(/'/g, "''") + "'";

const DEFAULT_CONFIG = [
  { stage_label: 'contato-instantaneo', delay_minutes: 0, next_label: 'primeiro-contato', trail: 'contato', step: 0 },
  { stage_label: 'primeiro-contato', delay_minutes: 2160, next_label: 'segundo-contato', trail: 'contato', step: 1 },
  { stage_label: 'segundo-contato', delay_minutes: 3300, next_label: 'terceiro-contato', trail: 'contato', step: 2 },
  { stage_label: 'terceiro-contato', delay_minutes: 4320, next_label: 'ultimo-contato', trail: 'contato', step: 3 },
  { stage_label: 'ultimo-contato', delay_minutes: 5760, next_label: 'arquivado', trail: 'contato', step: 4 },
  { stage_label: 'orcamento-instantaneo', delay_minutes: 0, next_label: 'orcamento-feito', trail: 'orcamento', step: 0 },
  { stage_label: 'orcamento-feito', delay_minutes: 2160, next_label: 'orcamento-tentativa-2', trail: 'orcamento', step: 1 },
  { stage_label: 'orcamento-tentativa-2', delay_minutes: 3300, next_label: 'orcamento-tentativa-3', trail: 'orcamento', step: 2 },
  { stage_label: 'orcamento-tentativa-3', delay_minutes: 4320, next_label: 'orcamento-tentativa-4', trail: 'orcamento', step: 3 },
  { stage_label: 'orcamento-tentativa-4', delay_minutes: 5760, next_label: 'arquivado', trail: 'orcamento', step: 4 },
  { stage_label: 'orcamento-5-dias', delay_minutes: 7200, next_label: 'orcamento-feito', trail: 'orcamento-coringa', step: 5 },
  { stage_label: 'orcamento-10-dias', delay_minutes: 14400, next_label: 'orcamento-feito', trail: 'orcamento-coringa', step: 10 },
  { stage_label: 'orcamento-15-dias', delay_minutes: 21600, next_label: 'orcamento-feito', trail: 'orcamento-coringa', step: 15 }
];

const ensureConfigSql = [
  "CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_config (stage_label text PRIMARY KEY, delay_minutes integer NOT NULL DEFAULT 0, next_label text, trail text, step integer, enabled boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now());",
  "INSERT INTO rotta_chatwoot_followup_config (stage_label, delay_minutes, next_label, trail, step) VALUES " +
    DEFAULT_CONFIG.map(row => "(" + q(row.stage_label) + "," + row.delay_minutes + "," + q(row.next_label) + "," + q(row.trail) + "," + row.step + ")").join(",") +
    " ON CONFLICT (stage_label) DO NOTHING;"
].join(" ");

const submittedConfig = Array.isArray(body.config)
  ? body.config
  : body.config && typeof body.config === 'object'
    ? [body.config]
    : [];
const configRows = submittedConfig.map(row => {
  const stageLabel = String(row.stage_label || row.label || '').toLowerCase().replace(/[^a-z0-9_-]/g, '').slice(0, 81);
  const delayMinutes = Math.max(0, Math.min(525600, Math.round(Number(row.delay_minutes ?? Number(row.delay_hours || 0) * 60) || 0)));
  return {
    stageLabel,
    delayMinutes,
    enabled: row.enabled !== false
  };
}).filter(row => row.stageLabel);

const configUpdateSql = configRows.length
  ? "INSERT INTO rotta_chatwoot_followup_config (stage_label, delay_minutes, enabled) VALUES " +
    configRows.map(row => "(" + q(row.stageLabel) + "," + row.delayMinutes + "," + row.enabled + ")").join(",") +
    " ON CONFLICT (stage_label) DO UPDATE SET delay_minutes=EXCLUDED.delay_minutes, enabled=EXCLUDED.enabled, updated_at=now();"
  : "";

let sql;
if (action === 'config') {
  sql = [ensureConfigSql, configUpdateSql, "SELECT stage_label, delay_minutes, next_label, trail, step, enabled, updated_at FROM rotta_chatwoot_followup_config ORDER BY step NULLS LAST, stage_label;"].filter(Boolean).join(" ");
} else if (action === 'list' && body.operational_only === true) {
  const listAccountId = Number(body.account_id);
  if (!Number.isSafeInteger(listAccountId) || listAccountId <= 0) throw new Error('Conta inválida para consultar follow-ups');
  const selectedJob = body.job_id ? ' AND j.job_id=' + q(String(body.job_id)) : '';
  sql = 'SELECT j.job_id,j.conversation_id,j.account_id,j.phone,j.customer_name,j.source_label,' +
    'COALESCE(c.stage_label,j.source_label) AS current_label,j.next_label,j.trail,j.step,j.scheduled_at,' +
    "j.status,j.attempts,j.error_message,COALESCE(c.history_json,'[]'::jsonb) AS history," +
    "COALESCE(c.active_labels,'[]'::jsonb) AS active_labels FROM rotta_chatwoot_followup_jobs j " +
    'LEFT JOIN rotta_chatwoot_followup_state c USING (conversation_id) WHERE j.account_id=' + listAccountId +
    " AND j.status IN ('pending','processing','failed_send','failed_labels')" + selectedJob +
    ' ORDER BY j.scheduled_at ASC NULLS LAST,j.job_id ASC;';
} else if (action === 'list') {
  sql = "CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_state (conversation_id bigint PRIMARY KEY, account_id bigint NOT NULL, phone text, customer_name text, active_labels jsonb NOT NULL DEFAULT '[]'::jsonb, stage_label text, trail text, step integer, last_event_id text, history_json jsonb NOT NULL DEFAULT '[]'::jsonb, updated_at timestamptz NOT NULL DEFAULT now()); ALTER TABLE rotta_chatwoot_followup_state ADD COLUMN IF NOT EXISTS history_json jsonb NOT NULL DEFAULT '[]'::jsonb; CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_jobs (job_id text PRIMARY KEY, conversation_id bigint NOT NULL, account_id bigint NOT NULL, phone text, customer_name text, source_label text NOT NULL, next_label text, trail text NOT NULL, step integer NOT NULL, scheduled_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'pending', attempts integer NOT NULL DEFAULT 0, payload jsonb, context_json jsonb, final_message text, sent_at timestamptz, sent_response jsonb, error_message text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()); WITH active_jobs AS (SELECT j.job_id,j.conversation_id,j.account_id,j.phone,j.customer_name,j.source_label,COALESCE(c.stage_label,j.source_label) AS current_label,j.next_label,j.trail,j.step,j.scheduled_at,j.status,j.attempts,j.error_message,COALESCE(c.history_json,'[]'::jsonb) AS history,COALESCE(c.active_labels,'[]'::jsonb) AS active_labels FROM rotta_chatwoot_followup_jobs j LEFT JOIN rotta_chatwoot_followup_state c USING (conversation_id) WHERE j.status IN ('pending','processing','failed_send','failed_labels')), active_conversations AS (SELECT DISTINCT conversation_id FROM active_jobs), sent_history AS (SELECT conversation_id,jsonb_agg(jsonb_build_object('label',source_label,'sent_at',COALESCE(sent_at,updated_at),'next_label',next_label) ORDER BY COALESCE(sent_at,updated_at)) AS history FROM rotta_chatwoot_followup_jobs WHERE status='sent' GROUP BY conversation_id), sent_jobs AS (SELECT DISTINCT ON (COALESCE(NULLIF(j.phone,''), 'conversation:' || j.conversation_id::text), COALESCE(c.stage_label,j.source_label)) j.job_id,j.conversation_id,j.account_id,j.phone,j.customer_name,j.source_label,COALESCE(c.stage_label,j.source_label) AS current_label,NULL::text AS next_label,COALESCE(c.trail,j.trail) AS trail,COALESCE(c.step,j.step) AS step,COALESCE(j.sent_at,j.updated_at) AS scheduled_at,'sent_history'::text AS status,j.attempts,NULL::text AS error_message,COALESCE(NULLIF(c.history_json,'[]'::jsonb),sh.history,'[]'::jsonb) AS history,COALESCE(c.active_labels,'[]'::jsonb) AS active_labels FROM rotta_chatwoot_followup_jobs j LEFT JOIN rotta_chatwoot_followup_state c USING (conversation_id) LEFT JOIN sent_history sh USING (conversation_id) WHERE j.status='sent' AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs newer WHERE newer.conversation_id=j.conversation_id AND newer.status IN ('no_send','failed_send','failed_labels') AND newer.updated_at > COALESCE(j.sent_at,j.updated_at)) ORDER BY COALESCE(NULLIF(j.phone,''), 'conversation:' || j.conversation_id::text), COALESCE(c.stage_label,j.source_label), COALESCE(j.sent_at,j.updated_at) DESC), state_history AS (SELECT 'state:' || c.conversation_id::text AS job_id,c.conversation_id,c.account_id,c.phone,c.customer_name,c.stage_label AS source_label,c.stage_label AS current_label,NULL::text AS next_label,c.trail,c.step,c.updated_at AS scheduled_at,'history_only'::text AS status,0 AS attempts,NULL::text AS error_message,COALESCE(c.history_json,'[]'::jsonb) AS history,COALESCE(c.active_labels,'[]'::jsonb) AS active_labels FROM rotta_chatwoot_followup_state c WHERE jsonb_array_length(COALESCE(c.history_json,'[]'::jsonb)) > 0), no_send_history AS (SELECT DISTINCT ON (COALESCE(NULLIF(j.phone,''), 'conversation:' || j.conversation_id::text), j.source_label) 'no-send:' || j.job_id AS job_id,j.conversation_id,j.account_id,j.phone,j.customer_name,j.source_label,COALESCE(c.stage_label,j.source_label) AS current_label,NULL::text AS next_label,COALESCE(c.trail,j.trail) AS trail,COALESCE(c.step,j.step) AS step,COALESCE(j.updated_at,j.created_at) AS scheduled_at,'history_only'::text AS status,j.attempts,j.error_message,COALESCE(c.history_json,'[]'::jsonb) AS history,COALESCE(c.active_labels,'[]'::jsonb) AS active_labels FROM rotta_chatwoot_followup_jobs j LEFT JOIN rotta_chatwoot_followup_state c USING (conversation_id) WHERE j.status='no_send' ORDER BY COALESCE(NULLIF(j.phone,''), 'conversation:' || j.conversation_id::text), j.source_label, COALESCE(j.updated_at,j.created_at) DESC) SELECT job_id,conversation_id,account_id,phone,customer_name,source_label,current_label,next_label,trail,step,scheduled_at,status,attempts,error_message,history,active_labels FROM active_jobs UNION ALL SELECT s.job_id,s.conversation_id,s.account_id,s.phone,s.customer_name,s.source_label,s.current_label,s.next_label,s.trail,s.step,s.scheduled_at,s.status,s.attempts,s.error_message,s.history,s.active_labels FROM sent_jobs s LEFT JOIN active_conversations a USING (conversation_id) WHERE a.conversation_id IS NULL UNION ALL SELECT h.job_id,h.conversation_id,h.account_id,h.phone,h.customer_name,h.source_label,h.current_label,h.next_label,h.trail,h.step,h.scheduled_at,h.status,h.attempts,h.error_message,h.history,h.active_labels FROM state_history h LEFT JOIN active_conversations a USING (conversation_id) LEFT JOIN sent_jobs s USING (conversation_id) WHERE a.conversation_id IS NULL AND s.conversation_id IS NULL AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs newer WHERE newer.conversation_id=h.conversation_id AND newer.status='no_send' AND newer.updated_at > h.scheduled_at) UNION ALL SELECT n.job_id,n.conversation_id,n.account_id,n.phone,n.customer_name,n.source_label,n.current_label,n.next_label,n.trail,n.step,n.scheduled_at,n.status,n.attempts,n.error_message,n.history,n.active_labels FROM no_send_history n LEFT JOIN active_conversations a USING (conversation_id) LEFT JOIN sent_jobs s USING (conversation_id) WHERE a.conversation_id IS NULL AND s.conversation_id IS NULL ORDER BY scheduled_at ASC NULLS LAST LIMIT 2000;";
} else if (action === 'delay' || action === 'advance') {
  const signed = action === 'delay' ? Math.abs(hours) : -Math.abs(hours);
  const indeterminateClause = "status='failed_send' AND (error_message ILIKE '%indeterminado%' OR error_message ILIKE '%timeout%')";
  const blockedQuery = "SELECT job_id,scheduled_at,status,'requires_review'::text AS action_result FROM rotta_chatwoot_followup_jobs WHERE job_id=" + q(jobId) + " AND " + indeterminateClause;
  const blockedCondition = " AND NOT (" + indeterminateClause + ")";
  sql = "WITH updated AS (UPDATE rotta_chatwoot_followup_jobs SET scheduled_at=scheduled_at + interval " + q(signed + ' hours') + ", status='pending', attempts=CASE WHEN status='pending' THEN attempts ELSE 0 END, error_message=NULL, updated_at=now() WHERE job_id=" + q(jobId) + " AND status IN ('pending','failed_send','failed_labels')" + blockedCondition + " RETURNING job_id,scheduled_at,status), blocked AS (" + blockedQuery + ") SELECT job_id,scheduled_at,status,'updated'::text AS action_result FROM updated UNION ALL SELECT job_id,scheduled_at,status,action_result FROM blocked UNION ALL SELECT job_id,scheduled_at,status,CASE WHEN status='processing' THEN 'already_processing' ELSE 'not_eligible' END AS action_result FROM rotta_chatwoot_followup_jobs WHERE job_id=" + q(jobId) + " AND NOT EXISTS (SELECT 1 FROM updated) AND NOT EXISTS (SELECT 1 FROM blocked) LIMIT 1;";
} else if (action === 'dispatch_now') {
  const indeterminateClause = "status='failed_send' AND (error_message ILIKE '%indeterminado%' OR error_message ILIKE '%timeout%')";
  const blockedQuery = "SELECT job_id,scheduled_at,status,'requires_review'::text AS action_result FROM rotta_chatwoot_followup_jobs WHERE job_id=" + q(jobId) + " AND " + indeterminateClause;
  const blockedCondition = " AND NOT (" + indeterminateClause + ")";
  sql = "WITH updated AS (UPDATE rotta_chatwoot_followup_jobs SET scheduled_at=now(), status='pending', attempts=CASE WHEN status='pending' THEN attempts ELSE 0 END, error_message=NULL, updated_at=now() WHERE job_id=" + q(jobId) + " AND status IN ('pending','failed_send','failed_labels')" + blockedCondition + " RETURNING job_id,scheduled_at,status), blocked AS (" + blockedQuery + ") SELECT job_id,scheduled_at,status,'scheduled'::text AS action_result FROM updated UNION ALL SELECT job_id,scheduled_at,status,action_result FROM blocked UNION ALL SELECT job_id,scheduled_at,status,CASE WHEN status='processing' THEN 'already_processing' ELSE 'not_eligible' END AS action_result FROM rotta_chatwoot_followup_jobs WHERE job_id=" + q(jobId) + " AND NOT EXISTS (SELECT 1 FROM updated) AND NOT EXISTS (SELECT 1 FROM blocked) LIMIT 1;";
} else if (action === 'cancel') {
  sql = "UPDATE rotta_chatwoot_followup_jobs SET status='cancelled', error_message='cancelado pelo painel', updated_at=now() WHERE job_id=" + q(jobId) + '; SELECT job_id,status FROM rotta_chatwoot_followup_jobs WHERE job_id=' + q(jobId) + ';';
} else {
  sql = "SELECT 'ação inválida' AS error;";
}
return [{ json: { action, sql, account_id: String(body.account_id || ''), conversations: Array.isArray(body.conversations) ? body.conversations : [] } }];
