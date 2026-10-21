# Label read/write ordering — 2026-10-20

## Confirmed cause

A labels GET started before a successful replacement could finish afterwards and
restore the old labels in both the labels store and root conversation. The minimal
replay reproduced KELVIN returning visually after the server saved orcamento-feito.
The inspected n8n event sample did not demonstrate a server-side reinsertion.

## Isolated correction

- Capture the conversation's mutation version and current read identity.
- Discard reads superseded by another read or a newer local mutation.
- Wait for writes already queued before issuing a new labels GET, without putting
  GETs into the write queue or delaying optimistic clicks.
- Recheck mutation versions after recovery GETs and before recovery rollback.
- Preserve later legitimate external changes and independent conversations.

No changes to backend writes, n8n, automatic-label eligibility, follow-up scheduling,
delivery, cancellation, or conversation routing.

## Validation

Before the fix, the actual-store deferred-HTTP replay restored KELVIN and failed.
After the fix, the same replay retains orcamento-feito and passes.

95 tests passed across 14 files, including nine read/write regression cases and
existing queue, rapid-change, bulk-action, review, and following tests. Targeted
ESLint passed. Vite compiled successfully; all 289 manifest assets exist.

New build: dashboard-Bqu1Y0bH.js. CSS differences from the previous build are only
Vue scoped-style identifiers, consistently regenerated with their components.
Existing hashed assets are retained for already-open sessions. Only newly
referenced assets and the manifest are packaged, not unrelated source-map churn.

Deployment and live UI validation must be recorded separately after completion;
local test success alone is not evidence that production was updated.
