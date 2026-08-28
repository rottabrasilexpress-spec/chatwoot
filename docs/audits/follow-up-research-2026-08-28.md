# Rotta follow-up reliability research — 2026-08-28

Scope: official/first-party sources only. Read-only review of the Rotta follow-up path, covering n8n webhook/execution behavior, Chatwoot webhooks/API/realtime/labels, UazAPI, and official WhatsApp material. The local Chatwoot checkout reports version `4.17.0`. No workflows, production code, or active files were changed.

## Executive findings

1. **Webhook latency can become message loss.** n8n documents that `responseNode`/“When Last Node Finishes” waits for downstream work, while “Immediately” acknowledges as soon as the workflow starts. Chatwoot’s current source sends account/API-inbox webhooks through an asynchronous `WebhookJob`, then `SafeFetch` uses a configurable `WEBHOOK_TIMEOUT` (default 5 seconds). The general `WebhookJob` has no `retry_on`; only the AgentBot subclass retries selected `429`/`500` failures. Therefore a slow n8n acknowledgment, queue delay, timeout, or swallowed HTTP error can lose a Chatwoot event unless the receiver and a reconciliation process cover it.

2. **n8n retries are opt-in and node-level.** n8n documents automatic retry only when a node has `retryOnFail` configured; retrying a failed workflow from the Executions UI is a manual operation. In the Rotta workflow, the AI, UazAPI, and Chatwoot HTTP nodes use `neverError: true` and do not configure `retryOnFail`; failures are therefore routed as returned data/branches, not as automatic retries. The AI path can turn an upstream error or empty response into the “no send” cancellation branch.

3. **A UazAPI 2xx is not sufficient proof of handset delivery.** UazAPI documents `track_source`/`track_id`, message lifecycle states (`Queued`, `Failed`, `Sent`, `Delivered`, `Read`), `messages` and `messages_update` webhook events, and `/message/find` filtering by tracking fields. It also documents an async queue and explicitly recommends excluding `wasSentByApi` to prevent automation loops. The official UazAPI OpenAPI material found here does not promise webhook retry, ordering, or idempotency; those properties must be verified empirically.

4. **Chatwoot label writes are replace operations.** Chatwoot documents that `POST /conversations/{id}/labels` overwrites the conversation’s existing label list. Rotta’s GET-merge-POST sequence can lose a concurrent label update. Chatwoot also exposes message pagination with `after` (up to 100 ascending messages), which is the appropriate recovery primitive for missed realtime/webhook events.

5. **Realtime is a delivery path, not a durable ledger.** Chatwoot’s first-party source broadcasts `message_created`, `message_updated`, and conversation events over Action Cable streams keyed by `pubsub_token`. The source shows no replay cursor in that broadcast path; this is an inference, so clients should reconnect and reconcile via the Messages API, deduplicating by Chatwoot message ID. Official Meta WhatsApp material likewise warns that status notification order may not match actual timing; correlate by message ID and provider timestamp.

## Evidence / Implications

### n8n

- The [Webhook node documentation](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/) separates test and production URLs, says production webhooks are registered when the workflow is published, and defines the response modes `Immediately`, `When Last Node Finishes`, and `Respond to Webhook`.
- [Error handling](https://docs.n8n.io/flow-logic/error-handling/) documents `retryOnFail`, `maxTries`, and `waitBetweenTries` at node level, and an error workflow for execution failures. [Execution documentation](https://docs.n8n.io/workflows/executions/all-executions/) describes retrying failed executions from the UI; it is not an automatic webhook redelivery contract.
- **Rotta implication:** the label webhook uses `responseMode: 'responseNode'`, and the response node follows PostgreSQL DDL/inserts. Its acknowledgment is consequently exposed to DB and n8n execution latency. HTTP nodes use `fullResponse: true, neverError: true`; inspect status codes explicitly and do not treat a completed n8n execution as proof that an external action succeeded.

### Chatwoot

- [Webhook subscriptions](https://developers.chatwoot.com/api-reference/webhooks/add-a-webhook) support `conversation_updated`, `message_created`, and `message_updated` among the documented events. The [official webhook listener](https://github.com/chatwoot/chatwoot/blob/develop/app/listeners/webhook_listener.rb) builds those payloads and enqueues `WebhookJob`.
- [Webhook delivery source](https://github.com/chatwoot/chatwoot/blob/develop/lib/webhooks/trigger.rb) posts JSON with `X-Chatwoot-Delivery` when present, applies open/read timeouts, and handles non-AgentBot failures internally. [Webhook job source](https://github.com/chatwoot/chatwoot/blob/develop/app/jobs/webhook_job.rb) shows the normal job signature; [AgentBot’s job](https://github.com/chatwoot/chatwoot/blob/develop/app/jobs/agent_bots/webhook_job.rb) is the exceptional path with targeted retries. The default timeout is visible in [installation config](https://github.com/chatwoot/chatwoot/blob/develop/config/installation_config.yml).
- [Conversation labels](https://developers.chatwoot.com/api-reference/conversations/add-labels) says the POST overwrites the existing label list; [list labels](https://developers.chatwoot.com/api-reference/conversations/list-labels) is the read side. [Conversation messages](https://developers.chatwoot.com/api-reference/messages/get-messages) supports `after` and returns up to 100 messages ascending.
- [Create message](https://developers.chatwoot.com/api-reference/messages/create-new-message) documents message status fields including `sent`, `delivered`, `read`, and `failed`; the public API also documents `echo_id` as a temporary identifier returned over websockets.
- [Realtime listener source](https://github.com/chatwoot/chatwoot/blob/develop/app/listeners/action_cable_listener.rb) broadcasts message/conversation events, and [RoomChannel source](https://github.com/chatwoot/chatwoot/blob/develop/app/channels/room_channel.rb) subscribes clients to the token stream. **Inference:** a disconnected client needs API backfill; realtime alone is not sufficient evidence of durable receipt.

### UazAPI and WhatsApp

- The official [UazAPI documentation](https://docs.uazapi.com/) and its [published OpenAPI document](https://docs.uazapi.com/openapi-bundled.json) document instance webhooks, `messages`/`messages_update`, filters including `wasSentByApi`, send-text responses and error codes, async queue state, lifecycle status fields, `track_id`/`track_source`, and `/message/find`.
- **UazAPI implication:** record a stable `track_id` per follow-up and verify the resulting message/status via `/message/find` and `messages_update`; separately measure delivery latency. Do not infer delivery from the first HTTP 200 alone. Treat retry/ordering semantics as unknown until tested against the actual instance.
- Meta’s official [WhatsApp webhook payload reference](https://www.postman.com/meta/whatsapp-business-platform/folder/tduohwq/webhook-payload-reference) identifies message/status webhook payloads and message IDs. Meta’s official [status notification reference](https://www.postman.com/meta/whatsapp-business-platform/request/rgtfq23/message-status-update-notifications) says status notification order may not reflect actual timing and recommends using timestamps. The official [WhatsApp SDK receiving guide](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/receivingMessages/) demonstrates returning HTTP 200 so the webhook service does not reattempt the notification.

## Failure modes to verify

| Boundary | Failure mode | Concrete pass criterion |
|---|---|---|
| Chatwoot → n8n | n8n response waits on PostgreSQL/queue and Chatwoot’s 5-second delivery timeout expires | Inject controlled 6–10 second delays; capture `X-Chatwoot-Delivery`, Chatwoot job/log outcome, n8n execution, and event count. No event may disappear silently; if delivery fails, a replay/reconciliation path must recover it. |
| Chatwoot → n8n | Duplicate or repeated `conversation_updated` delivery creates duplicate follow-up jobs | Send/replay the same payload twice and concurrently; assert one durable event/job per `(conversation_id, stage, delivery identity)`. Persist and deduplicate the `X-Chatwoot-Delivery` value rather than deriving identity from `body.id`, `event`, or timestamps. |
| n8n → provider | `neverError` hides a timeout/429/5xx and the flow cancels or marks a job without retry | Stub AI/UazAPI/Chatwoot endpoints with timeout, 429, 500, malformed 2xx, and delayed 2xx. Assert each result is classified correctly, has bounded retry/alert behavior, and never becomes an unexplained “no send.” |
| UazAPI → WhatsApp | HTTP acceptance, queueing, or a later provider failure is mistaken for delivery | Send with unique `track_source`/`track_id`; correlate `/message/find`, UazAPI webhook updates, lifecycle status, and recipient observation. A follow-up is “delivered” only when the provider status supports it. |
| Label update | Concurrent GET-merge-POST overwrites a human/API label or triggers a stage race | Update a sentinel label concurrently with Rotta’s stage label; assert the sentinel survives and exactly one next-stage job exists. Record the response and subsequent Chatwoot `conversation_updated` payload. |
| UazAPI loop | API-originated outgoing message re-enters the inbound automation | Confirm the webhook configuration uses `excludeMessages: ["wasSentByApi"]`, or prove an equivalent idempotency guard; an API send must not create a new Rotta follow-up event. |
| Realtime/recovery | WebSocket disconnect or out-of-order status hides a message or regresses state | Disconnect the client during multiple messages, reconnect, backfill with Chatwoot `GET .../messages?after=<last_id>`, and compare IDs/content. Replay status events out of order and require monotonic state handling based on provider timestamps/status rank. |

## Recommended verification artifacts

- A cross-system trace keyed by `conversation_id`, Chatwoot message ID, `X-Chatwoot-Delivery`, UazAPI `messageid`, and Rotta `job_id`/`track_id`.
- Counts for: Chatwoot webhook deliveries, n8n executions and node attempts, UazAPI HTTP outcomes, provider lifecycle updates, and final recipient-visible messages.
- A dead-letter/reconciliation report for events/jobs in `processing`, `failed_send`, or `failed_labels`, plus a periodic Chatwoot/UazAPI backfill check.

