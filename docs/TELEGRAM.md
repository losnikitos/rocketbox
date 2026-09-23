# Telegram

Inbound media from the bot (photos, video, docs, etc.) for customer content. Text-only messages get a RubyLLM reply with a `list_media` tool.

## Flow

1. Telegram POSTs updates to `POST /telegram/webhook` ([routes](/config/routes.rb)).
2. [TelegramWebhooksController](/app/controllers/telegram_webhooks_controller.rb) skips CSRF/auth, optionally checks `X-Telegram-Bot-Api-Secret-Token` against credentials, then enqueues [ProcessTelegramUpdateJob](/app/jobs/process_telegram_update_job.rb).
3. The job persists an [IncomingMessage](/app/models/incoming_message.rb) ([StoreIncomingMessage](/app/services/store_incoming_message.rb); failures logged, not raised), then branches:
   - **Media** → [StoreTelegramMedia](/app/services/store_telegram_media.rb): extract media → skip if `telegram_file_unique_id` already stored → download via Bot API → create [LibraryMedia](/app/models/library_media.rb) with Active Storage attachment → 👍 reaction on the message (failures logged, not raised). Caption-only context on media messages is not sent to the LLM.
   - **Text-only** → [ReplyTelegramMessage](/app/services/reply_telegram_message.rb): resolve user by `telegram_user_id` → create a [Chat](/app/models/chat.rb) → ask with [ListMedia](/app/tools/list_media.rb) → `send_message` the reply.
4. Ownership: if `message.from.id` matches a user’s `telegram_user_id`, the media is attached to that user (`library_media.user_id`). Unmatched media is still stored. Saving a Telegram user id on Account backfills orphan media with that `from_id`. Media appears on `/account`. Unlinked text senders still get an LLM reply; `list_media` tells them to link Account → Integrations.

Supported kinds: photo (largest size), document, video, audio, voice, video_note, animation, sticker. Edited messages are handled the same as new ones.

## Credentials

Under `telegram` in Rails credentials:

- `bot_token` — required; used by [TelegramBot](/app/services/telegram_bot.rb)
- `webhook_secret` — optional; if set, webhook requests must send the matching secret header

xAI key for replies: `xai.api_key` (see [ruby_llm initializer](/config/initializers/ruby_llm.rb)).

Gems: `telegram-bot-ruby`, `ruby_llm` in [Gemfile](/Gemfile).

## Ops

- **Production webhook:** `rails telegram:set_webhook[https://host/telegram/webhook]` ([telegram.rake](/lib/tasks/telegram.rake)) — registers the URL and secret token when present.
- **Local/dev:** `rails telegram:poll` — deletes the webhook, long-polls, runs the same job synchronously for Message payloads.

## Key files

| Role | Path |
|------|------|
| API client | [app/services/telegram_bot.rb](/app/services/telegram_bot.rb) |
| Webhook | [app/controllers/telegram_webhooks_controller.rb](/app/controllers/telegram_webhooks_controller.rb) |
| Job | [app/jobs/process_telegram_update_job.rb](/app/jobs/process_telegram_update_job.rb) |
| Store media | [app/services/store_telegram_media.rb](/app/services/store_telegram_media.rb) |
| LLM reply | [app/services/reply_telegram_message.rb](/app/services/reply_telegram_message.rb) |
| List media tool | [app/tools/list_media.rb](/app/tools/list_media.rb) |
| Model | [app/models/library_media.rb](/app/models/library_media.rb) |
| Library UI | [app/views/accounts/show.html.erb](/app/views/accounts/show.html.erb) (`/account`) |
| Migration | [db/migrate/20260919120000_create_telegram_uploads.rb](/db/migrate/20260919120000_create_telegram_uploads.rb) (renamed to `library_media` in later migration) |
| Rake | [lib/tasks/telegram.rake](/lib/tasks/telegram.rake) |
| Tests | [test/services/store_telegram_media_test.rb](/test/services/store_telegram_media_test.rb), [test/tools/list_media_test.rb](/test/tools/list_media_test.rb) |
