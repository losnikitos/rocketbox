# Deploy

Production runs on a single VPS via **Kamal** + **Docker**. There is no Heroku (or other PaaS) target; local process layout lives only in [`Procfile.dev`](/Procfile.dev).

## Host and domain

- App hostname: `rocketbox.plus` (allowed in [`config/environments/production.rb`](/config/environments/production.rb); mailer host via `MAILER_DEFAULT_HOST`)
- Deploy target: `monitoring.tadaaa.uk.com` ([`config/deploy.yml`](/config/deploy.yml))
- TLS: `kamal-proxy` + Let’s Encrypt (`ssl: true`). Proxy binds the public IP only so Tailscale’s `:443` is free. With Cloudflare in front, use SSL mode **Full**.
- Health check: `GET /up` (SSL redirect and host authorization skip this path)

## Image and deploy

- Config: [`config/deploy.yml`](/config/deploy.yml)
- CLI: [`bin/kamal`](/bin/kamal) (gem `kamal` in [`Gemfile`](/Gemfile))
- Image: `ghcr.io/<KAMAL_REGISTRY_USERNAME>/rocketbox`, built amd64 from [`Dockerfile`](/Dockerfile)
- Runtime: Thruster → Rails (`./bin/thrust ./bin/rails server`); [`bin/docker-entrypoint`](/bin/docker-entrypoint) runs `db:prepare` before boot
- Persistent volume: `rocketbox_storage` → `/rails/storage` (SQLite + app storage)

Useful aliases: `bin/kamal console`, `shell`, `logs`, `dbc`.

## Secrets and credentials

Kamal secrets: [`.kamal/secrets`](/.kamal/secrets). Expects from local `.env` (loaded by direnv via [`.envrc`](/.envrc)):

- `KAMAL_REGISTRY_USERNAME` / `KAMAL_REGISTRY_PASSWORD` (GHCR PAT: `write:packages`, `read:packages`)
- `RAILS_MASTER_KEY` from [`config/master.key`](/config/master.key) (never commit)

Injected into the container: `RAILS_MASTER_KEY`. App secrets (Stripe, Telegram, Postmark, Notion, etc.) live in encrypted Rails credentials (`bin/rails credentials:edit` → [`config/credentials.yml.enc`](/config/credentials.yml.enc)), decrypted with that master key.

Clear env from deploy config includes `SOLID_QUEUE_IN_PUMA=true` and `MAILER_DEFAULT_HOST=rocketbox.plus`.

## Data, jobs, files

- SQLite multi-DB (primary / cache / queue / cable) under `storage/` — [`config/database.yml`](/config/database.yml)
- Solid Queue runs inside Puma when `SOLID_QUEUE_IN_PUMA` is set ([`config/puma.rb`](/config/puma.rb)); recurring cleanup in [`config/recurring.yml`](/config/recurring.yml). A separate `job` role / `bin/jobs` is commented for later multi-server use.
- Solid Cache + Solid Cable in production ([`config/environments/production.rb`](/config/environments/production.rb))
- Active Storage service `:vps` — disk root from `ACTIVE_STORAGE_ROOT` (default `/var/lib/rocketbox/storage`) in [`config/storage.yml`](/config/storage.yml)
- Mail: Postmark ([`config/application.rb`](/config/application.rb)); default from `MAIL_FROM` / `noreply@rocketbox.plus`

## Local vs production processes

[`bin/dev`](/bin/dev) + [`Procfile.dev`](/Procfile.dev): web (port 3000), Tailwind watch, Stripe CLI forward, Telegram long-poll. Production uses HTTPS webhooks for Stripe and Telegram instead of those local processes.

After deploy, point Telegram at the live webhook (see Telegram docs / `rails telegram:set_webhook[...]`).

## CI

[`.github/workflows/ci.yml`](/.github/workflows/ci.yml) on PRs and pushes to `main`: Brakeman, bundler-audit, importmap audit, RuboCop, `test`, `test:system`. Dependabot: [`.github/dependabot.yml`](/.github/dependabot.yml) (bundler + GitHub Actions, weekly).
