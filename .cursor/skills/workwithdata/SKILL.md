---
name: workwithdata
description: Work on application data (query, seed, backfill, fix rows) via rails runner instead of writing code. Use when the user says /workwithdata, asks to change DB records, inspect production data, or run a one-off data fix.
disable-model-invocation: true
---

# Work with data

Do the task by **running** against the database. Do **not** write app code, migrations, or scripts unless the user explicitly asks for a lasting change in the repo.

Data-only changes that must persist across deploys still belong in a data migration (`bin/rails g data_migration …`) — use that only when the user wants a committed, repeatable change. For ad-hoc inspect/fix/seed in a session, use runner.

## Environments

| Environment | How |
|-------------|-----|
| **Local** (default) | `bin/rails runner '…'` |
| **Production** | `bin/kamal app exec --reuse "bin/rails runner '…'"` |

Use local unless the user says production / remote / live / rocketbox.plus.

Aliases for production ops (console, shell, logs): see [DEPLOY.md](/docs/DEPLOY.md). Prefer one-shot `app exec --reuse` + runner over an interactive console unless they ask for a REPL.

## How to work

1. Confirm environment (local vs production).
2. Inspect with a small read-only runner snippet first when the target rows are unclear.
3. Mutate with an explicit runner snippet; print what changed (ids, counts, before/after).
4. Prefer ActiveRecord and existing model APIs over raw SQL.
5. Destructive production writes: show the exact command and what it will touch; wait for confirmation unless the user already approved that change.

## Runner examples

Local count:

```bash
bin/rails runner 'puts Post.count'
```

Production find + update:

```bash
bin/kamal app exec --reuse "bin/rails runner 'p = Post.find(2); p.update!(title: \"New\"); puts p.reload.attributes.slice(\"id\", \"title\")'"
```

Multiline local (quotes matter — prefer single-quoted Ruby inside double-quoted shell when nesting under kamal):

```bash
bin/rails runner '
post = Post.find(2)
puts post.frames.pluck(:id, :position, :rule_number).inspect
'
```
