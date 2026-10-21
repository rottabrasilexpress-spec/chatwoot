const fs = require('node:fs');
const assert = require('node:assert/strict');
const code = fs.readFileSync('n8n/follow-up/panel-action.js', 'utf8');
const normalize = new Function('$json', code);
const result = normalize({ body: { action: 'list', account_id: 1, operational_only: true } })[0].json;
assert(!result.sql.includes('sent_history'), 'Operational list still loads historical rows');
assert(!result.sql.includes('LIMIT 2000'), 'Historical limit can hide future active jobs');
assert(result.sql.includes('j.account_id=1'), 'Operational list must be account scoped');
assert(/^SELECT\b/.test(result.sql), 'Operational list must be read-only');
const one = normalize({ body: { action: 'list', account_id: 1, operational_only: true, job_id: 'job-123' } })[0].json;
assert(one.sql.includes("j.job_id='job-123'"), 'Single-job authorization must not load the entire queue');
for (const bad of [undefined, 0, -1, '1 OR 1=1']) {
  assert.throws(() => normalize({ body: { action: 'list', account_id: bad, operational_only: true } }));
}
assert(normalize({ body: { action: 'list' } })[0].json.sql.includes('sent_history'), 'Legacy audit list must remain available');
console.log('PASS: read-only operational query, account isolation, full future coverage, bounded job lookup, legacy audit preserved.');
