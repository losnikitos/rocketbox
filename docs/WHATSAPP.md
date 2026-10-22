# WhatsApp

Inbound media from WhatsApp Cloud API (photos, video, docs, audio, stickers) for customer content. Text-only messages get a reply from [RocketboxAgent](/app/agents/rocketbox_agent.rb). Its system prompt lists what we know about the business.

## Flow

1. Meta POSTs updates to `POST /whatsapp/webhook` ([routes](/config/routes.rb)). Initial hub verification uses `GET /whatsapp/webhook`.
2. [WhatsappWebhooksController](/app/controllers/whatsapp_webhooks_controller.rb) skips CSRF/auth, verifies `hub.verify_token` on GET, optionally checks `X-Hub-Signature-256` against `app_secret` on POST, then enqueues [ProcessWhatsappUpdateJob](/app/jobs/process_whatsapp_update_job.rb).
3. The job persists an [IncomingMessage](/app/models/incoming_message.rb) per message ([StoreIncomingMessage](/app/services/store_incoming_message.rb); failures logged, not raised), then branches:
   - **Media** → [StoreWhatsappMedia](/app/services/store_whatsapp_media.rb): extract media → skip if `whatsapp_media_id` already stored → download via Graph API → create [LibraryMedia](/app/models/library_media.rb) with Active Storage attachment → 👍 reaction on the message (failures logged, not raised).
   - **Link** (`START_<code>`, prefilled on `/app/whatsapp`) → `WhatsappOnboarding.link!` sets the sender as the `whatsapp_phone` of the account whose `users.whatsapp_link_code` matches (e.g. an email-only account), rotates the code (one-time), replies “WhatsApp connected.” and starts the onboarding chain. One phone per account: a number already on another account, or an account that already has a different number, is refused; an unknown code gets an “expired” reply. No account is created either way.
   - **Unknown phone** → [ReplyWhatsappMessage](/app/services/reply_whatsapp_message.rb) creates a user for that `whatsapp_phone` and starts onboarding (business card).
   - **Start** (`START`, case-insensitive, prefilled by `/sign_up`) → restarts the onboarding chain on the existing user.
   - **Onboarding answer** → text or a button reply to the pending `brand_voice` / `email` step is saved and the chain moves on (see Onboarding), no LLM reply. Other pending steps are resent, except `business_card`, `logo`, and their processing steps, which fall through.
   - **Links** → text with `http(s)://` URLs from a known phone → each URL saved as a [Link](/app/models/link.rb) (`source: "whatsapp"`, deduped per user) → 👍 reaction, no LLM reply. Links appear on `/app/links`.
   - **Approval** (`approval:approve:<id>` / `approval:reject:<id>` button reply) → approve or reject a waiting Approval step run owned by that user ([RequestApproval](/app/services/request_approval.rb)); see [WORKFLOWS.md](./WORKFLOWS.md). Approve does not send its own ack — the next step's WhatsApp line is the reply.
   - **Waiting step** (known phone, no onboarding question) → the newest `waiting` step run owned by that user is the cursor. Text resends that step (Approval resends its buttons). A photo that lands in a waiting Collect's start folder joins that run instead of opening another ([Workflow.autorun!](/app/models/workflow.rb)).
   - **Text-only** (known phone, nothing waiting — including free-form text during the business-card and logo steps) → [RocketboxAgent](/app/agents/rocketbox_agent.rb) ([ListMedia](/app/tools/list_media.rb), [LoginLink](/app/tools/login_link.rb), [SaveBusiness](/app/tools/save_business.rb)) → `send_text` the reply. [SaveBusiness](/app/tools/save_business.rb) writes facts they state. The pending step stays set so the next photo still files. A business-card photo is still read by the [Business card workflow](/app/models/workflow/business_card.rb), not the agent.
4. Ownership: if `messages.from` matches a user’s `whatsapp_phone`, the media is attached to that user (`library_media.user_id`). Unmatched media is still stored. Media appears on `/app/library`.

## Dashboard page

`/app/whatsapp` ([controller](/app/controllers/accounts/whatsapp_controller.rb), sidebar after Instagram) is that account's WhatsApp thread: their messages on the right, Rocketbox on the left, with a reaction's emoji on the message it targets. The connection card sits above the thread: the linked number and **Disconnect**, which clears `whatsapp_phone` and the pending onboarding step. With no phone connected, the page shows a `wa.me` link + QR code prefilled with `START_<whatsapp_link_code>` ([shared/_whatsapp_qr](/app/views/shared/_whatsapp_qr.html.erb), also used by `/sign_up`), and any earlier messages under it. The code is created on first view for accounts that don't have one yet. Owners can't type a phone: it's set only by messaging us (proves they own the number) — `START_<code>` links it to their account; any other first text from an unknown number creates a new account and starts onboarding. Admins get a menu on each bubble ([incoming](/app/views/shared/admin_links/_incoming_message.html.erb), [outgoing](/app/views/shared/admin_links/_outgoing_message.html.erb)) and can still edit the phone in Active Admin.

Supported kinds: image (stored as `photo`), video, audio, document, sticker.

## Onboarding

An automatic chain run by [WhatsappOnboarding](/app/services/whatsapp_onboarding.rb). The copy lives in `MESSAGES`. `ask!` sends a step's message and stores the step in `whatsapp_pending_question`; the reply runs the step and asks the next one:

1. `business_card` — the photo lands in `inbox/business-card`; the autorun [Business card workflow](/app/models/workflow/business_card.rb) extracts fields onto the user and a logo into `photobank/logo`. Pending stays `processing_business_card` until the run settles, then onboarding asks for Instagram or a logo photo. Text during this step, `logo`, or either processing step goes to [RocketboxAgent](/app/agents/rocketbox_agent.rb) instead of resending the prompt.
2. `logo` — only if the card gave no logo; the photo lands in `inbox/logo` and the same workflow runs. The account logo is the newest media in `photobank/logo` ([User#logo_media](/app/models/user.rb)), not an ActiveStorage attachment on the user.
3. `instagram` — Autopilot pitch + **Connect Instagram** URL button (one-time login link) that lands on Instagram authorize. The OAuth callback ([InstagramAuthorizationsController](/app/controllers/accounts/instagram_authorizations_controller.rb)) sends `instagram_connected` and moves on.
4. `interior_back` (sent as the example photo `public/onboarding/barbershop-example.jpg` with the copy as caption), then `interior_front` — both photos are tagged `interior`.
5. `brand_voice` — Classic / Bold / Wild reply buttons (typing the word works too); saved to `users.brand_voice`, also editable on `/app/business`.
6. `email` — saved to `users.email` (sends the verification mail); an invalid address re-asks.

On `/app/onboarding` (any user sees their own; admins see the selected account) each step has **Ask in chat** to (re)start the chain from there. **Send dashboard link** sends a one-time `/sign_in/whatsapp` link ([LOGIN.md](./LOGIN.md)). Links go out as `cta_url` interactive messages (`WhatsappOnboarding.send_link!`): a URL button instead of a raw link; body ≤ 1024 chars, button ≤ 20. Links and the example photo use `https://rocketbox.plus` in production and `https://dev.rocketbox.plus` elsewhere (`WhatsappOnboarding::URL_OPTIONS`), so the tunnel must be up in dev.

Admin-triggered messages go out from `WhatsappCloud.phone_number_id` (prod line in production, test line elsewhere). Free-form messages only deliver within Meta's 24h window after the user's last message; outside it the error shows as a flash alert.

## Credentials

Under `whatsapp` in Rails credentials:

- `access_token` — required; Graph API token used by [WhatsappCloud](/app/services/whatsapp_cloud.rb). Generate via Meta Business Settings (tadaaa portfolio, `1235592620332534`) > System users > `61594834930452`. Needs full control of the app and both the test and prod WABAs.
- `app_secret` — optional; if set, webhook POSTs must send a matching `X-Hub-Signature-256`
- `webhook_verify_token` — required for Meta hub verification; same string as in the Meta webhook “Verify token” field

xAI key for replies: `xai.api_key` (see [ruby_llm initializer](/config/initializers/ruby_llm.rb)).

Every send (text, image, buttons, `cta_url`, reaction) goes through `WhatsappCloud.send_message!`, which stores an [OutgoingMessage](/app/models/outgoing_message.rb) with the request payload, the `wamid` as `external_id`, or the `error` if the send failed (`/admin/outgoing_messages`, filter by user). Login links are visible there too.

Replies and reactions go out from the number that received the message (`metadata.phone_number_id` in the webhook), so dev and prod need no per-env sender config. `WhatsappCloud.display_phone` (the `wa.me` START link on `/sign_up`) is the prod number in production and the test number elsewhere.

## Ops

One Meta app serves both lines. App-level webhook → `https://rocketbox.plus/whatsapp/webhook`; the test number has a phone-level override → dev (`POST /1369590492903246` with `webhook_configuration.override_callback_uri` + `verify_token`, tunnel must be up; check with `GET /1369590492903246?fields=webhook_configuration`).

Sandbox / test line — reference only:

| What | Value |
|------|-------|
| Display number | `+15551540920` / `15551540920` (humans text this; webhook `metadata.display_phone_number`) |
| Phone number ID | `1369590492903246` |
| WhatsApp Business account ID (WABA) | `1997100320969487` (`entry[].id`) |
| Dev sender (Nikita) | `447919397572` (`messages[].from` / `contacts[].wa_id` — link as `users.whatsapp_phone`) |

Production line:

| What | Value |
|------|-------|
| Display number | `+44 7451 273884` / `447451273884` |
| Phone number ID | `1344349375436017` |
| WhatsApp Business account ID (WABA) | `2946448049053569` |

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
      "id": "1997100320969487",
      "changes": [
        {
          "field": "messages",
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "15551540920",
              "phone_number_id": "1369590492903246"
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
| Agent | [app/agents/rocketbox_agent.rb](/app/agents/rocketbox_agent.rb) |
| Onboarding chain / links | [app/services/whatsapp_onboarding.rb](/app/services/whatsapp_onboarding.rb) |
| List media tool | [app/tools/list_media.rb](/app/tools/list_media.rb) |
| Save business tool | [app/tools/save_business.rb](/app/tools/save_business.rb) |
| Model | [app/models/library_media.rb](/app/models/library_media.rb) |
| Library UI | [app/views/accounts/show.html.erb](/app/views/accounts/show.html.erb) (`/app/library`) |
| Tests | [test/services/store_whatsapp_media_test.rb](/test/services/store_whatsapp_media_test.rb), [test/services/reply_whatsapp_message_test.rb](/test/services/reply_whatsapp_message_test.rb), [test/controllers/whatsapp_webhooks_controller_test.rb](/test/controllers/whatsapp_webhooks_controller_test.rb) |
