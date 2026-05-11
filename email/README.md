# Rocketbox transactional email (React Email → Postmark)

Author templates as React components under `emails/`, preview with the dev server, export HTML, and sync to Postmark with the official CLI (same flow as tadaaa-backend’s `email/`).

## Setup

```bash
cd email
npm install
```

Install the [Postmark CLI](https://github.com/wildbit/postmark-cli) globally (or use `npx postmark` and adjust the `Makefile`).

## Workflow

- `npm run dev` — local preview
- `make postmark-export` or `npm run export` — write HTML to `out/` (gitignored)
- `make postmark-copy-html` — copy `out/<name>.html` → `postmark/<name>/content.html`
- `make postmark-pull` — download existing templates from Postmark into `postmark/`
- `make postmark-push` — upload `postmark/` to Postmark
- `make postmark-sync` — pull → export → copy HTML → push

Rails sends with `postmark_template_alias` values `password_reset`, `email_verification`, and `demo_chapter` (must match folder names under `postmark/`).

## CLI authentication

`postmark templates pull` and `postmark templates push` need a **server API token** for the Postmark server you use for this app. Set:

`export POSTMARK_SERVER_TOKEN="your-server-api-token"`

That is the same kind of token as `Rails.application.credentials.postmark_api_token` (the transactional server token), unless you use a separate server for templates.

You can also run `postmark login` once to store credentials for the CLI (see the Postmark CLI README).
