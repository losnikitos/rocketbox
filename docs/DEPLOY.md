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

Injected into the container: `RAILS_MASTER_KEY`. App secrets (Stripe, Telegram, Postmark, etc.) live in encrypted Rails credentials (`bin/rails credentials:edit` → [`config/credentials.yml.enc`](/config/credentials.yml.enc)), decrypted with that master key.

Clear env from deploy config includes `SOLID_QUEUE_IN_PUMA=true` and `MAILER_DEFAULT_HOST=rocketbox.plus`.

## Data, jobs, files

- SQLite multi-DB (primary / cache / queue / cable) under `storage/` — [`config/database.yml`](/config/database.yml)
- Solid Queue runs inside Puma when `SOLID_QUEUE_IN_PUMA` is set ([`config/puma.rb`](/config/puma.rb)); recurring cleanup in [`config/recurring.yml`](/config/recurring.yml). A separate `job` role / `bin/jobs` is commented for later multi-server use.
- Solid Cache + Solid Cable in production ([`config/environments/production.rb`](/config/environments/production.rb))
- Active Storage service `:vps` — disk root from `ACTIVE_STORAGE_ROOT` (default `/var/lib/rocketbox/storage`) in [`config/storage.yml`](/config/storage.yml)
- Mail: Postmark ([`config/application.rb`](/config/application.rb)); default from `MAIL_FROM` / `noreply@rocketbox.plus`

## Local vs production processes

[`bin/dev`](/bin/dev) + [`Procfile.dev`](/Procfile.dev): web (port 3003), Solid Queue (`bin/jobs`), Tailwind watch, Stripe CLI forward, Telegram long-poll. Production uses HTTPS webhooks for Stripe and Telegram instead of those local processes; jobs run inside Puma via `SOLID_QUEUE_IN_PUMA`.

After deploy, point Telegram at the live webhook (see Telegram docs / `rails telegram:set_webhook[...]`).

## CI

[`.github/workflows/ci.yml`](/.github/workflows/ci.yml) on PRs and pushes to `main`: Brakeman, bundler-audit, importmap audit, RuboCop, `test`, `test:system`. Dependabot: [`.github/dependabot.yml`](/.github/dependabot.yml) (bundler + GitHub Actions, weekly).

## GitHub Actions deploy

[`.github/workflows/deploy.yml`](/.github/workflows/deploy.yml) runs `bin/kamal deploy` on push to `main` (and manually via **Actions → Deploy → Run workflow**). Builds amd64 on the runner, pushes to GHCR with `GITHUB_TOKEN`, SSHs to `monitoring.tadaaa.uk.com`.

Repo secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|--------|
| `RAILS_MASTER_KEY` | Contents of [`config/master.key`](/config/master.key) |
| `SSH_PRIVATE_KEY` | Private key whose public half is in `root`’s `authorized_keys` on the VPS |
| `KAMAL_REGISTRY_USERNAME` | Same as local `.env` (GitHub username, e.g. `losnikitos`) |
| `KAMAL_REGISTRY_PASSWORD` | GHCR PAT with `write:packages` / `read:packages` (same as local `.env`) |

`GITHUB_TOKEN` is not enough here: the package was first pushed with a personal PAT, so Actions’ token gets `permission_denied: read_package` on push. Use the same registry credentials as local Kamal.
