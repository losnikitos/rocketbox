# Prompts

Service prompts (crawl, business card, media improve) live in the `Prompt` table ([prompt.rb](/app/models/prompt.rb)), looked up by `key` via `Prompt.body_for!(key)`. Code never holds prompt text.

Content prompts are not here: each recipe has its own `prompt` (edited at `/app/recipes`), sent to the single AI call of each generation (`Generation#run!`).

A copy of every prompt is kept in git as [`prompts/<key>.md`](/prompts/) — the file is the body verbatim, no frontmatter.

## Sync

| Command | Direction |
|---------|-----------|
| `make prompts-push` / `bin/rails prompts:push` | files → DB, upsert by key |
| `make prompts-pull` / `bin/rails prompts:pull` | DB → files |

- Production pushes on every boot ([docker-entrypoint](/bin/docker-entrypoint)), so files win on deploy. Active Admin edits in prod survive only until the next deploy — bring them back with `make restore-prod-to-local` (it ends with `prompts:pull`) and commit.
- [seeds.rb](/db/seeds.rb) pushes too, so a fresh DB has every prompt.
- Neither direction deletes orphans.

## Tests

[prompts.yml](/test/fixtures/prompts.yml) builds fixtures from `prompts/*.md`, so tests see the real bodies.
