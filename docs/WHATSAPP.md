# WhatsApp

Inbound media from WhatsApp Cloud API (photos, video, docs, audio, stickers) for customer content. Text-only messages get a RubyLLM reply with a `list_media` tool.

## Flow

1. Meta POSTs updates to `POST /whatsapp/webhook` ([routes](/config/routes.rb)). Initial hub verification uses `GET /whatsapp/webhook`.
2. [WhatsappWebhooksController](/app/controllers/whatsapp_webhooks_controller.rb) skips CSRF/auth, verifies `hub.verify_token` on GET, optionally checks `X-Hub-Signature-256` against `app_secret` on POST, then enqueues [ProcessWhatsappUpdateJob](/app/jobs/process_whatsapp_update_job.rb).
3. The job persists an [IncomingMessage](/app/models/incoming_message.rb) per message ([StoreIncomingMessage](/app/services/store_incoming_message.rb); failures logged, not raised), then branches:
   - **Media** → [StoreWhatsappMedia](/app/services/store_whatsapp_media.rb): extract media → skip if `whatsapp_media_id` already stored → download via Graph API → create [LibraryMedia](/app/models/library_media.rb) with Active Storage attachment → 👍 reaction on the message (failures logged, not raised).
   - **Start** (`START`, case-insensitive, prefilled by `/sign_up`) → [ReplyWhatsappMessage](/app/services/reply_whatsapp_message.rb) finds or creates the user by `whatsapp_phone` (no email), backfills orphan media, and replies with the welcome (“you can already start sending photos and videos”). Repeating `START` just re-sends the welcome.
   - **Onboarding answer** → if the sender has `whatsapp_pending_question`, the text is saved to that field (`name`, `business_name`, `homepage_url`), the question is cleared, 👍 reaction, no LLM reply.
   - **Links** → [ReplyWhatsappMessage](/app/services/reply_whatsapp_message.rb): text with `http(s)://` URLs from a linked phone → each URL saved as a [Link](/app/models/link.rb) (`source: "whatsapp"`, deduped per user) → 👍 reaction, no LLM reply. Links appear on `/app/links`. Unlinked senders fall through to the LLM reply.
   - **Text-only** → [ReplyWhatsappMessage](/app/services/reply_whatsapp_message.rb): resolve user by `whatsapp_phone` → create a [Chat](/app/models/chat.rb) → ask with [ListMedia](/app/tools/list_media.rb) → `send_text` the reply.
4. Ownership: if `messages.from` matches a user’s `whatsapp_phone`, the media is attached to that user (`library_media.user_id`). Unmatched media is still stored. Saving a WhatsApp phone on Account backfills orphan media with that `whatsapp_from`. Media appears on `/app/library`. Unlinked text senders still get an LLM reply; `list_media` tells them to link Account → Integrations.

Supported kinds: image (stored as `photo`), video, audio, document, sticker.

## Onboarding

Nothing is asked automatically. On `/app/onboarding` (admin, selected account) each missing step has **Ask in chat** — [WhatsappOnboarding](/app/services/whatsapp_onboarding.rb) sends the scripted question from `QUESTIONS` and sets `whatsapp_pending_question`; the next text reply fills it. Instagram's “Ask in chat” sends a one-time login link that lands on Instagram authorize. **Send dashboard link** sends a one-time `/sign_in/whatsapp` link ([LOGIN.md](./LOGIN.md)). Links use the host the admin is browsing, so use `https://dev.rocketbox.plus` in dev.

Admin-triggered messages go out from `WhatsappCloud.phone_number_id` (prod line in production, test line elsewhere). Free-form messages only deliver within Meta's 24h window after the user's last message; outside it the error shows as a flash alert.

## Credentials

Under `whatsapp` in Rails credentials:

- `access_token` — required; Graph API token used by [WhatsappCloud](/app/services/whatsapp_cloud.rb). Generate via Meta Business Settings > System users > Nikita (`61594348875817`). Needs access to both the test and prod WABAs.
- `app_secret` — optional; if set, webhook POSTs must send a matching `X-Hub-Signature-256`
- `webhook_verify_token` — required for Meta hub verification; same string as in the Meta webhook “Verify token” field

xAI key for replies: `xai.api_key` (see [ruby_llm initializer](/config/initializers/ruby_llm.rb)).

Replies and reactions go out from the number that received the message (`metadata.phone_number_id` in the webhook), so dev and prod need no per-env sender config. `WhatsappCloud.display_phone` (the `wa.me` START link on `/sign_up`) is the prod number in production and the test number elsewhere.

## Ops

One Meta app serves both lines. App-level webhook → `https://rocketbox.plus/whatsapp/webhook`; the test number has a phone-level override → dev (`POST /1238456642695224` with `webhook_configuration.override_callback_uri` + `verify_token`, tunnel must be up; check with `GET /1238456642695224?fields=webhook_configuration`).

Sandbox / test line — reference only:

| What | Value |
|------|-------|
| Display number | `+15551712639` / `15551712639` (humans text this; webhook `metadata.display_phone_number`) |
| Phone number ID | `1238456642695224` |
| WhatsApp Business account ID (WABA) | `2195816907943950` (`entry[].id`) |
| Dev sender (Nikita) | `447919397572` (`messages[].from` / `contacts[].wa_id` — link as `users.whatsapp_phone`) |

Production line:

| What | Value |
|------|-------|
| Display number | `+44 7451 273884` / `447451273884` |
| Phone number ID | `1237261782813765` |

- **Dev callback host:** `https://dev.rocketbox.plus` (SSH reverse tunnel → local `:3003`; see [deploy.yml](/config/deploy.yml) `dev-tunnel` / `make tunnel`). Meta callback: `https://dev.rocketbox.plus/whatsapp/webhook`.
- **Meta dashboard:** callback URL `https://host/whatsapp/webhook` (prod) or the dev URL above, subscribe to the `messages` field, paste `webhook_verify_token`.
- Needs a Meta App with the WhatsApp product and a connected WhatsApp Business phone number.

### Sample inbound text webhook (Meta dump, trimmed)

Fields we care about: `entry[].id` (WABA), `metadata.phone_number_id` / `display_phone_number`, `messages[].from` + `id` + `type` (+ media or `text.body`). Ignore Meta-only extras (`internal_1p_only_data`, `from_user_id`, `from_logical_id`, etc.).

```json
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "2195816907943950",
      "changes": [
        {
          "field": "messages",
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "15551712639",
              "phone_number_id": "1238456642695224"
            },
            "contacts": [
              {
                "profile": { "name": "Nikita" },
                "wa_id": "447919397572"
              }
            ],
            "messages": [
              {
                "from": "447919397572",
                "id": "wamid.HBgMNDQ3OTE5Mzk3NTcyFQIAEhgUM0IwMTYxNzNBQjNENkQ3MEQ4OUYA",
                "timestamp": "1790201693",
                "type": "text",
                "text": { "body": "hi" }
              }
            ]
          }
        }
      ]
    }
  ]
}
```

## Key files

| Role | Path |
|------|------|
| API client | [app/services/whatsapp_cloud.rb](/app/services/whatsapp_cloud.rb) |
| Webhook | [app/controllers/whatsapp_webhooks_controller.rb](/app/controllers/whatsapp_webhooks_controller.rb) |
| Job | [app/jobs/process_whatsapp_update_job.rb](/app/jobs/process_whatsapp_update_job.rb) |
| Store media | [app/services/store_whatsapp_media.rb](/app/services/store_whatsapp_media.rb) |
| LLM reply | [app/services/reply_whatsapp_message.rb](/app/services/reply_whatsapp_message.rb) |
| Onboarding questions / links | [app/services/whatsapp_onboarding.rb](/app/services/whatsapp_onboarding.rb) |
| List media tool | [app/tools/list_media.rb](/app/tools/list_media.rb) |
| Model | [app/models/library_media.rb](/app/models/library_media.rb) |
| Library UI | [app/views/accounts/show.html.erb](/app/views/accounts/show.html.erb) (`/app/library`) |
| Tests | [test/services/store_whatsapp_media_test.rb](/test/services/store_whatsapp_media_test.rb), [test/services/reply_whatsapp_message_test.rb](/test/services/reply_whatsapp_message_test.rb), [test/controllers/whatsapp_webhooks_controller_test.rb](/test/controllers/whatsapp_webhooks_controller_test.rb) |
