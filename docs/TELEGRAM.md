# Telegram

Inbound media from the bot (photos, video, docs, etc.) for customer content. Text-only messages are ignored.

## Flow

1. Telegram POSTs updates to `POST /telegram/webhook` ([routes](/config/routes.rb)).
2. [TelegramWebhooksController](/app/controllers/telegram_webhooks_controller.rb) skips CSRF/auth, optionally checks `X-Telegram-Bot-Api-Secret-Token` against credentials, then enqueues [ProcessTelegramUpdateJob](/app/jobs/process_telegram_update_job.rb).
3. The job calls [StoreTelegramMedia](/app/services/store_telegram_media.rb): extract media → skip if `telegram_file_unique_id` already stored → download via Bot API → create [TelegramUpload](/app/models/telegram_upload.rb) with Active Storage attachment → 👍 reaction on the message (failures logged, not raised).
4. Ownership: if `message.from.id` matches a user’s `telegram_user_id`, the upload is attached to that user (`telegram_uploads.user_id`). Unmatched media is still stored. Saving a Telegram user id on Account backfills orphan uploads with that `from_id`. Media appears on `/library`.

Supported kinds: photo (largest size), document, video, audio, voice, video_note, animation, sticker. Edited messages are handled the same as new ones.

## Credentials

Under `telegram` in Rails credentials:

- `bot_token` — required; used by [TelegramBot](/app/services/telegram_bot.rb)
- `webhook_secret` — optional; if set, webhook requests must send the matching secret header

Gem: `telegram-bot-ruby` in [Gemfile](/Gemfile).

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
| Model | [app/models/telegram_upload.rb](/app/models/telegram_upload.rb) |
| Library UI | [app/views/libraries/show.html.erb](/app/views/libraries/show.html.erb) (`/library`) |
| Migration | [db/migrate/20260919120000_create_telegram_uploads.rb](/db/migrate/20260919120000_create_telegram_uploads.rb) |
| Rake | [lib/tasks/telegram.rake](/lib/tasks/telegram.rake) |
| Test | [test/services/store_telegram_media_test.rb](/test/services/store_telegram_media_test.rb) |
