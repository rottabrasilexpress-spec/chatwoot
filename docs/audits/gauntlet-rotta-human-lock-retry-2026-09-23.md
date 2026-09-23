# Gauntlet — RottaWoot human-lock retry

Date: 2026-09-23  
Baseline: `df2dcdf654cb7499898693191eedd54a8ab1dc1c`  
Work branch: `fix/rotta-human-lock-signal-20260923`

## Scope

Only the human-intervention handshake before UAZAPI send. A human message must
remain fail-closed until n8n confirms the pause; when that confirmation fails,
the unsent message must be safely retryable. No customer messages or Docker.

## Finding

`Messages::SendOnApiService#perform_reply` claimed the UAZAPI send before asking
n8n to register the human intervention. On handshake failure, the code marked
the message failed but retained `rotta_uazapi_pending_echo`. A retry therefore
looked like a duplicate claim and returned before trying the handshake again,
even though UAZAPI had never been called. The active n8n workflow uses
`message_id` as its event key, so repeated handshakes are deduplicated there.

The production workflow is active and expects the `X-RottaWoot-Human-Token`
header. At the time of inspection, the matching EasyPanel variables
`ROTTABRASIL_HUMAN_LOCK_WEBHOOK_URL` and
`ROTTABRASIL_HUMAN_LOCK_WEBHOOK_TOKEN` were absent. This is an app-to-workflow
configuration gap, not evidence that the active workflow's event logic is
broken. The Header Auth credential is referenced only by the human-intervention
webhook node in that workflow.

## Checkpoints

1. Test checkpoint `aec6bce0`: updated the failure expectation and added a
   failed-handshake-then-retry regression spec.
2. Fix checkpoint `485f3dae`: clears only the local pending-echo claim when the
   pre-send human-lock handshake fails; clears the stale lock-warning marker on
   a later valid acknowledgment. It does not call UAZAPI unless n8n confirms.
3. Test checkpoint `f46b2202`: asserts a successful UAZAPI retry clears the old
   failure and covers a successful response that has no provider message ID.
4. Fix checkpoint `1d46b5d8`: after UAZAPI returns 2xx, persist acceptance under
   a row lock, clear stale delivery errors, set `sent` unless a concurrent
   webhook already advanced it to `delivered`/`read`, and retain echo matching
   when the response lacks a provider ID.
5. `git diff --check` passed. Local RSpec was attempted but unavailable because
   this workstation has no Ruby/Bundler runtime. GitHub Actions specs that boot
   Postgres/Redis containers were not invoked (Docker is prohibited). CircleCI
   is not logged in on this machine, so no remote test result is available yet.
6. Static inspection of the published n8n version confirmed a primary key on
   `message_id` plus `ON CONFLICT` deduplication; retrying the same signal does
   not create a second human event. An independent review found no duplicate
   WhatsApp send path from releasing the claim before UAZAPI is called.
7. The feature branch was pushed to GitHub. It has not been merged or deployed.

## Remaining gate

The new shared secret must be entered by the user in the exclusive n8n Header
Auth credential and in the two named EasyPanel variables. Browser policy
requires user handoff for entering/changing authentication credentials. After
that, verify the matching header name, webhook URL, persisted environment, and
deployment; then run the focused spec on a non-Docker runner and a synthetic
handshake/retry test. Do not claim production-ready until those checks pass.
