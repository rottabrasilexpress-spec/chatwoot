const snapshots = $('Preparar snapshots de Primeiro contato').all().map(item => item.json);
const responses = $input.all().map(item => item.json);
const allowedStages = new Set([
  'primeiro-contato','segundo-contato','terceiro-contato','ultimo-contato',
  'orcamento-feito','orcamento-tentativa-2','orcamento-tentativa-3','orcamento-tentativa-4',
  'orcamento-5-dias','orcamento-10-dias','orcamento-15-dias'
]);
const rejected = [];
const accepted = [];
const normalizeLabel = value => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/^\d+\s*/, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
for (let index = 0; index < snapshots.length; index += 1) {
  const snapshot = snapshots[index];
  const response = responses[index] || {};
  const statusCode = Number(response.statusCode || response.status || 0);
  let body = response.body ?? response;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  const values = Array.isArray(body?.payload) ? body.payload : Array.isArray(body?.labels) ? body.labels : Array.isArray(body) ? body : [];
  const labels = values.map(value => typeof value === 'string' ? value : value?.title || value?.name || value?.label || value?.slug || '');
  const stage = normalizeLabel(snapshot.stage_label);
  if (statusCode < 200 || statusCode >= 300) {
    rejected.push({ conversation_id: String(snapshot.conversation_id), error: 'Chatwoot não confirmou as etiquetas (HTTP ' + statusCode + ')' });
    continue;
  }
  if (!allowedStages.has(stage)) {
    rejected.push({ conversation_id: String(snapshot.conversation_id), error: 'Etapa instantânea ou inválida não pode ser recuperada automaticamente' });
    continue;
  }
  if (!labels.some(label => normalizeLabel(label) === stage)) {
    rejected.push({ conversation_id: String(snapshot.conversation_id), error: 'A etiqueta da etapa não está mais ativa no Chatwoot' });
    continue;
  }
  accepted.push({ ...snapshot, stage_label: stage, active_labels: [stage] });
}
const q = value => value === null || value === undefined ? 'NULL' : "'" + String(value).replace(/'/g, "''") + "'";
const jsonSql = value => q(JSON.stringify(value)) + '::jsonb';
const rejectedSql = jsonSql(rejected);
if (!accepted.length) return [{ json: { sql: "SELECT 0::integer AS created, 0::integer AS verified, 0::integer AS checked, " + rejectedSql + " AS rejected;", action: 'reconcile' } }];
const values = accepted.map(row => "(" + row.conversation_id + "::bigint," + row.account_id + "::bigint," + q(row.phone) + "," + q(row.customer_name) + "," + jsonSql(row.active_labels) + "," + q(row.stage_label) + "," + q(row.source_updated_at) + "::timestamptz," + q("reconcile:" + row.account_id + ":" + row.conversation_id + ":" + row.stage_label + ":" + row.source_updated_at) + ")").join(",");
const incomingCte = "WITH incoming(conversation_id,account_id,phone,customer_name,active_labels,stage_label,source_updated_at,event_id) AS (VALUES " + values + ") ";
const defaultConfig = [
  { stage_label:'contato-instantaneo', delay_minutes:0, next_label:'primeiro-contato', trail:'contato', step:0 },
  { stage_label:'primeiro-contato', delay_minutes:2160, next_label:'segundo-contato', trail:'contato', step:1 },
  { stage_label:'segundo-contato', delay_minutes:3300, next_label:'terceiro-contato', trail:'contato', step:2 },
  { stage_label:'terceiro-contato', delay_minutes:4320, next_label:'ultimo-contato', trail:'contato', step:3 },
  { stage_label:'ultimo-contato', delay_minutes:5760, next_label:'arquivado', trail:'contato', step:4 },
  { stage_label:'orcamento-instantaneo', delay_minutes:0, next_label:'orcamento-feito', trail:'orcamento', step:0 },
  { stage_label:'orcamento-feito', delay_minutes:2160, next_label:'orcamento-tentativa-2', trail:'orcamento', step:1 },
  { stage_label:'orcamento-tentativa-2', delay_minutes:3300, next_label:'orcamento-tentativa-3', trail:'orcamento', step:2 },
  { stage_label:'orcamento-tentativa-3', delay_minutes:4320, next_label:'orcamento-tentativa-4', trail:'orcamento', step:3 },
  { stage_label:'orcamento-tentativa-4', delay_minutes:5760, next_label:'arquivado', trail:'orcamento', step:4 },
  { stage_label:'orcamento-5-dias', delay_minutes:7200, next_label:'orcamento-feito', trail:'orcamento-coringa', step:5 },
  { stage_label:'orcamento-10-dias', delay_minutes:14400, next_label:'orcamento-feito', trail:'orcamento-coringa', step:10 },
  { stage_label:'orcamento-15-dias', delay_minutes:21600, next_label:'orcamento-feito', trail:'orcamento-coringa', step:15 }
];
const defaultConfigValues = defaultConfig.map(row => "(" + q(row.stage_label) + "," + row.delay_minutes + "," + q(row.next_label) + "," + q(row.trail) + "," + row.step + ")").join(",");
const persistence = [
  "CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_state (conversation_id bigint PRIMARY KEY, account_id bigint NOT NULL, phone text, customer_name text, active_labels jsonb NOT NULL DEFAULT '[]'::jsonb, stage_label text, trail text, step integer, last_event_id text, source_updated_at timestamptz, last_received_at timestamptz, history_json jsonb NOT NULL DEFAULT '[]'::jsonb, updated_at timestamptz NOT NULL DEFAULT now());",
  "ALTER TABLE rotta_chatwoot_followup_state ADD COLUMN IF NOT EXISTS source_updated_at timestamptz;",
  "ALTER TABLE rotta_chatwoot_followup_state ADD COLUMN IF NOT EXISTS last_received_at timestamptz;",
  "ALTER TABLE rotta_chatwoot_followup_state ADD COLUMN IF NOT EXISTS history_json jsonb NOT NULL DEFAULT '[]'::jsonb;",
  "CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_jobs (job_id text PRIMARY KEY, conversation_id bigint NOT NULL, account_id bigint NOT NULL, phone text, customer_name text, source_label text NOT NULL, next_label text, trail text NOT NULL, step integer NOT NULL, scheduled_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'pending', attempts integer NOT NULL DEFAULT 0, payload jsonb, context_json jsonb, final_message text, sent_at timestamptz, sent_response jsonb, error_message text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());",
  "CREATE TABLE IF NOT EXISTS rotta_chatwoot_followup_config (stage_label text PRIMARY KEY, delay_minutes integer NOT NULL DEFAULT 0, next_label text, trail text, step integer, enabled boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now());",
  "INSERT INTO rotta_chatwoot_followup_config (stage_label,delay_minutes,next_label,trail,step) VALUES " + defaultConfigValues + " ON CONFLICT (stage_label) DO NOTHING;"
].join(" ");
const activeStatuses = "('pending','processing','sending','failed_send','failed_labels')";
const stateUpsert = incomingCte +
  "INSERT INTO rotta_chatwoot_followup_state AS current_state (conversation_id,account_id,phone,customer_name,active_labels,stage_label,trail,step,last_event_id,source_updated_at,last_received_at) " +
  "SELECT i.conversation_id,i.account_id,i.phone,i.customer_name,i.active_labels,i.stage_label,config.trail,config.step,i.event_id,i.source_updated_at,clock_timestamp() " +
  "FROM incoming i JOIN rotta_chatwoot_followup_config config ON config.stage_label=i.stage_label AND config.enabled IS TRUE " +
  "WHERE NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active WHERE active.conversation_id=i.conversation_id AND active.status IN " + activeStatuses + ") " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active_phone WHERE regexp_replace(COALESCE(active_phone.phone,''),'[^0-9]','','g')=i.phone AND active_phone.status IN " + activeStatuses + ") " +
  "ON CONFLICT (conversation_id) DO UPDATE SET account_id=EXCLUDED.account_id,phone=COALESCE(NULLIF(EXCLUDED.phone,''),current_state.phone),customer_name=COALESCE(NULLIF(EXCLUDED.customer_name,''),current_state.customer_name),active_labels=EXCLUDED.active_labels,stage_label=EXCLUDED.stage_label,trail=EXCLUDED.trail,step=EXCLUDED.step,last_event_id=EXCLUDED.last_event_id,source_updated_at=GREATEST(EXCLUDED.source_updated_at,current_state.source_updated_at),last_received_at=clock_timestamp(),updated_at=now() " +
  "WHERE current_state.account_id=EXCLUDED.account_id " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active WHERE active.conversation_id=EXCLUDED.conversation_id AND active.status IN " + activeStatuses + ") " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active_phone WHERE regexp_replace(COALESCE(active_phone.phone,''),'[^0-9]','','g')=regexp_replace(COALESCE(EXCLUDED.phone,''),'[^0-9]','','g') AND active_phone.status IN " + activeStatuses + ");";
const jobInsert = "INSERT INTO rotta_chatwoot_followup_jobs (job_id,conversation_id,account_id,phone,customer_name,source_label,next_label,trail,step,scheduled_at,status,payload) " +
  "SELECT 'cw-reconcile:'||state.conversation_id::text||':'||state.stage_label||':'||(EXTRACT(EPOCH FROM incoming.source_updated_at)*1000000)::bigint::text,state.conversation_id,state.account_id,state.phone,state.customer_name,state.stage_label,config.next_label,config.trail,config.step,now()+make_interval(mins=>config.delay_minutes),'pending',jsonb_build_object('source','chatwoot_label_reconciliation','source_updated_at',incoming.source_updated_at) " +
  "FROM state_rows state JOIN incoming ON incoming.conversation_id=state.conversation_id AND incoming.account_id=state.account_id AND incoming.stage_label=state.stage_label " +
  "JOIN rotta_chatwoot_followup_config config ON config.stage_label=state.stage_label AND config.enabled IS TRUE " +
  "WHERE state.active_labels @> jsonb_build_array(incoming.stage_label) " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active WHERE active.conversation_id=state.conversation_id AND active.status IN " + activeStatuses + ") " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active_phone WHERE regexp_replace(COALESCE(active_phone.phone,''),'[^0-9]','','g')=incoming.phone AND active_phone.status IN " + activeStatuses + ") " +
  "AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs previous WHERE previous.conversation_id=state.conversation_id AND previous.source_label=state.stage_label AND (previous.status IN ('sent','no_send') OR (previous.status='cancelled' AND COALESCE(previous.error_message,'') NOT IN ('etiqueta da trilha alterada','etiqueta da trilha removida','etiqueta da trilha removida antes da confirmação autoritativa'))) AND previous.updated_at>=incoming.source_updated_at) " +
  "ON CONFLICT DO NOTHING RETURNING job_id,conversation_id,source_label";
const finalQuery = incomingCte +
  ", locked_incoming AS MATERIALIZED (SELECT incoming.*,pg_advisory_xact_lock(hashtext('rotta_followup_reconcile:'||incoming.phone)) AS phone_lock FROM incoming ORDER BY incoming.phone,incoming.conversation_id), " +
  "state_rows AS (SELECT state.* FROM rotta_chatwoot_followup_state state JOIN locked_incoming incoming ON incoming.conversation_id=state.conversation_id AND incoming.account_id=state.account_id), " +
  "inserted AS (" + jobInsert.replace("FROM state_rows state JOIN incoming ON incoming.conversation_id=state.conversation_id AND incoming.account_id=state.account_id AND incoming.stage_label=state.stage_label", "FROM state_rows state JOIN locked_incoming incoming ON incoming.conversation_id=state.conversation_id AND incoming.account_id=state.account_id AND incoming.stage_label=state.stage_label") + "), " +
  "verified AS (SELECT COUNT(*)::integer AS count FROM incoming i JOIN rotta_chatwoot_followup_state state ON state.conversation_id=i.conversation_id AND state.account_id=i.account_id AND state.stage_label=i.stage_label AND state.active_labels @> jsonb_build_array(i.stage_label) WHERE (EXISTS (SELECT 1 FROM inserted created WHERE created.conversation_id=i.conversation_id AND created.source_label=i.stage_label) OR EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active WHERE active.conversation_id=i.conversation_id AND active.source_label=i.stage_label AND active.status IN " + activeStatuses + "))), " +
  "db_rejected AS (SELECT COALESCE(jsonb_agg(jsonb_build_object('conversation_id',i.conversation_id::text,'error',CASE WHEN config.stage_label IS NULL THEN 'A etapa não tem configuração de follow-up.' WHEN config.enabled IS NOT TRUE THEN 'A etapa está desativada na configuração de follow-up.' WHEN state.conversation_id IS NULL OR state.stage_label IS DISTINCT FROM i.stage_label OR NOT (state.active_labels @> jsonb_build_array(i.stage_label)) THEN 'A etiqueta mudou ou o estado ficou mais recente durante a reconciliação.' ELSE 'A fila não confirmou a inscrição; verifique se já existe outro job ativo para a conversa ou telefone.' END)),'[]'::jsonb) AS errors FROM incoming i LEFT JOIN rotta_chatwoot_followup_config config ON config.stage_label=i.stage_label LEFT JOIN rotta_chatwoot_followup_state state ON state.conversation_id=i.conversation_id AND state.account_id=i.account_id WHERE NOT EXISTS (SELECT 1 FROM inserted created WHERE created.conversation_id=i.conversation_id AND created.source_label=i.stage_label) AND NOT EXISTS (SELECT 1 FROM rotta_chatwoot_followup_jobs active WHERE active.conversation_id=i.conversation_id AND active.source_label=i.stage_label AND active.status IN " + activeStatuses + ")), " +
  "inserted_count AS (SELECT COUNT(*)::integer AS count FROM inserted) " +
  "SELECT inserted_count.count AS created,verified.count AS verified," + accepted.length + "::integer AS checked," + rejectedSql + "||db_rejected.errors AS rejected FROM inserted_count CROSS JOIN verified CROSS JOIN db_rejected";
const sql = [persistence,stateUpsert,finalQuery].join("\n");
return [{ json: { sql, action: 'reconcile' } }];
