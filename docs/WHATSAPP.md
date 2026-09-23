# WhatsApp

Inbound media from WhatsApp Cloud API (photos, video, docs, audio, stickers) for customer content. Text-only messages get a RubyLLM reply with a `list_media` tool.

## Flow

1. Meta POSTs updates to `POST /whatsapp/webhook` ([routes](/config/routes.rb)). Initial hub verification uses `GET /whatsapp/webhook`.
2. [WhatsappWebhooksController](/app/controllers/whatsapp_webhooks_controller.rb) skips CSRF/auth, verifies `hub.verify_token` on GET, optionally checks `X-Hub-Signature-256` against `app_secret` on POST, then enqueues [ProcessWhatsappUpdateJob](/app/jobs/process_whatsapp_update_job.rb).
3. The job branches:
   - **Media** → [StoreWhatsappMedia](/app/services/store_whatsapp_media.rb): extract media → skip if `whatsapp_media_id` already stored → download via Graph API → create [LibraryMedia](/app/models/library_media.rb) with Active Storage attachment → 👍 reaction on the message (failures logged, not raised).
   - **Text-only** → [ReplyWhatsappMessage](/app/services/reply_whatsapp_message.rb): resolve user by `whatsapp_phone` → create a [Chat](/app/models/chat.rb) → ask with [ListMedia](/app/tools/list_media.rb) → `send_text` the reply.
4. Ownership: if `messages.from` matches a user’s `whatsapp_phone`, the media is attached to that user (`library_media.user_id`). Unmatched media is still stored. Saving a WhatsApp phone on Account backfills orphan media with that `whatsapp_from`. Media appears on `/account`. Unlinked text senders still get an LLM reply; `list_media` tells them to link Account → Integrations.

Supported kinds: image (stored as `photo`), video, audio, document, sticker.

## Credentials

Under `whatsapp` in Rails credentials:

- `access_token` — required; Graph API token used by [WhatsappCloud](/app/services/whatsapp_cloud.rb)
- `phone_number_id` — required; Cloud API phone number id (not the display number)
- `app_secret` — optional; if set, webhook POSTs must send a matching `X-Hub-Signature-256`
- `webhook_verify_token` — required for Meta hub verification; same string as in the Meta webhook “Verify token” field

xAI key for replies: `xai.api_key` (see [ruby_llm initializer](/config/initializers/ruby_llm.rb)).

## Ops

- **Meta dashboard:** callback URL `https://host/whatsapp/webhook`, subscribe to the `messages` field, paste `webhook_verify_token`.
- Needs a Meta App with the WhatsApp product and a connected WhatsApp Business phone number.

## Key files

| Role | Path |
|------|------|
| API client | [app/services/whatsapp_cloud.rb](/app/services/whatsapp_cloud.rb) |
| Webhook | [app/controllers/whatsapp_webhooks_controller.rb](/app/controllers/whatsapp_webhooks_controller.rb) |
| Job | [app/jobs/process_whatsapp_update_job.rb](/app/jobs/process_whatsapp_update_job.rb) |
| Store media | [app/services/store_whatsapp_media.rb](/app/services/store_whatsapp_media.rb) |
| LLM reply | [app/services/reply_whatsapp_message.rb](/app/services/reply_whatsapp_message.rb) |
| List media tool | [app/tools/list_media.rb](/app/tools/list_media.rb) |
| Model | [app/models/library_media.rb](/app/models/library_media.rb) |
| Library UI | [app/views/accounts/show.html.erb](/app/views/accounts/show.html.erb) (`/account`) |
| Tests | [test/services/store_whatsapp_media_test.rb](/test/services/store_whatsapp_media_test.rb), [test/controllers/whatsapp_webhooks_controller_test.rb](/test/controllers/whatsapp_webhooks_controller_test.rb) |
