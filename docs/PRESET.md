# Preset + Posts (Studio)

Admin tool for **Rocketbox’s own promo** ads (not customer SMM workflows).

- **Preset** — coded formula (Ruby subclass, no index/show). Base [`Preset`](/app/models/preset.rb) holds shared size (9×16), scene helpers and image resolution; each preset is a subclass (e.g. [`Preset::GuidePromo`](/app/models/preset/guide_promo.rb)) with hard-coded CTA and scene formula. Referenced by slug (`guide-promo`). Guide promo formula: before → (overlay → frame)×n → CTA; 1..n selected rules → matching scenes.
- **Post** — DB entity. References a preset by slug; settings are source image, sequence of rules, and transition type. Generated key frames (`PostFrame`) and MP4 renders hang off the post. Previewed as a film strip of every scene, rendered to MP4. Full CRUD in Studio.

## Where

Sidebar → **Studio**:

| Tool | Path | Notes |
|------|------|--------|
| Media bank | [`/app/media_bank`](/app/media_bank) | Tagged reference photos (`Folder.bank`); each item at `/app/media_bank/:id` |
| Posts | [`/app/posts`](/app/posts) | CRUD, scene preview, settings, MP4 export |

Open locally with an admin account (e.g. `?account=5` on prod). Example: http://localhost:3003/app/posts

## Post settings (right panel)

Per post:

- **Preset** — coded preset slug (`guide-promo`)
- **Source image** — Media bank item id chosen from the dropdown — this is **v0**
- **Rules** — ordered sequence picked from the guide’s rules (add / remove / reorder)
- **Transition** — fade type used in the MP4 (and preview stand-in)

CTA text/href stay hard-coded on the preset subclass (read-only in the panel). Overlay copy comes from [`GuideRule`](/app/models/guide_rule.rb) rows for that guide, not from the post.

**Save**, then **Render video**. When the job finishes, **Download** the MP4.

The show page film strip is the main preview — every scene at once. Right-panel settings apply to the whole post.

Changing **source** or **rules** destroys all `PostFrame`s and `PostRender`s (stale key frames and MP4s). Changing **transition** destroys renders only.

## Key frames (`PostFrame`)

Each generated still after a rule is a `PostFrame`: `position` (1 = v1, 2 = v2, …), `rule_number` (how it was made today), Active Storage `file`. Scenes hold the bank `LibraryMedia` or `PostFrame` records directly. Source id stays on the post; frames live on the post. Today frames come from rule + image generation (demo seeds attach public compare JPGs); other generators can land here later.

## Guide promo defaults

[`Preset::GuidePromo`](/app/models/preset/guide_promo.rb) ensures an empty Post via `Post.ensure_defaults!` (no source, no rules, simple fade, no frames). Pick a Media bank source and rules on the post; generate frames after that.

With a source and rules but no frames yet, overlays stack on that source, then the shared CTA; fades run between those frames in the MP4 once frames exist.

Scene formula once filled in: before → (overlay → transition → frame)×n → CTA. CTA: comment “guide” → `/guides/barbershop`.

## Rendering pipeline

| Stage | Status | How |
|-------|--------|-----|
| Still + overlay + CTA frames | Live | Ferrum HTML/Tailwind ([`Layer.screenshot`](/app/models/layer.rb)) |
| Transitions in preview | Live | CSS stand-in labeled “Simple fade” |
| MP4 assembly | Live | [`PostRenderJob`](/app/jobs/post_render_job.rb) — hold each frame, `xfade` fade, attach to [`PostRender`](/app/models/post_render.rb) |
| AI transitions (Kling / Runway) | Later | Extra transition types beside simple fade |

MP4: render from the settings panel → `GET /app/post_renders/:id`

## Local run

```bash
bin/dev
# sign in as admin → Studio → Posts
# pick a Media bank image (by id) in the post’s source dropdown → Save → Render video
```

Ferrum needs Chrome/Chromium (same as Layers). ffmpeg on PATH for real MP4s (`RENDER_MEDIA=1` in tests). Tests mock ffmpeg unless that flag is set.

## Media bank

Seed / sync: `bin/rails media_bank:seed`, `media_bank:export`, `media_bank:import`. Browse/upload at `/app/media_bank` (group by shop, filter by tag); open an item to set tags. Posts pick bank items from the source dropdown. Tags include `barbershop`, `storefront`, plus shop slugs.
