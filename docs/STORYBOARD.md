# Storyboard + Posts (Studio)

Admin tool for **Rocketbox’s own promo** ads (not customer SMM workflows).

- **Storyboard** — coded preset (Ruby, no index/show). Hard-coded overlays, CTA, transition and scene formula. Referenced by id (`guide-promo`). Current formula: before → (overlay → after)×n → CTA; 1..n selected rules → matching scenes.
- **Post** — DB entity. References a storyboard by id; settings are source image + sequence of rules. Previewed scene-by-scene, rendered to MP4. Full CRUD in Studio.

## Where

Sidebar → **Studio**:

| Tool | Path | Notes |
|------|------|--------|
| Media bank | [`/app/media_bank`](/app/media_bank) | Tagged reference photos (`Folder.bank`); each item at `/app/media_bank/:id` |
| Posts | [`/app/posts`](/app/posts) | CRUD, scene preview, settings, PNG + MP4 export |

Open locally with an admin account (e.g. `?account=5` on prod). Example: http://localhost:3003/app/posts

## Post settings (right panel)

Per post:

- **Name**
- **Storyboard** — coded preset id (`guide-promo`)
- **Source image** — public path (`/guides/…`) or Media bank item URL (`/app/media_bank/:id`)
- **Rules** — which hard-coded overlays from the storyboard apply

Overlays, CTA and transition are fixed on the storyboard preset (read-only in the panel).

**Save**, then **Render video**. When the job finishes, **Download** the MP4. Scene PNG export remains for still / overlay / CTA.

Film strip switches scenes (`?scene=`).

## Guide promo defaults

[`guide-promo`](/app/models/storyboard.rb) seeds a default Post via `Post.ensure_defaults!` using the public barbershop compare set:

1. **v0** — before (`cluttered.jpg`)
2. **Overlay · rule #10** — “Keep the facade clear”
3. **Transition** — simple fade → clear facade
4. **v1** — `clean.jpg`
5. **Overlay · rule #12** — “Use warm light”
6. **Transition** — simple fade → warm
7. **v2** — `warm.jpg`
8. **CTA** — comment “guide” → `/guides/barbershop`

A media-bank (or other non-default) source stacks overlays on that source, then the shared CTA; fades run between those frames in the MP4.

## Rendering pipeline

| Stage | Status | How |
|-------|--------|-----|
| Still + overlay + CTA frames | Live | Ferrum HTML/Tailwind ([`Layer.screenshot`](/app/models/layer.rb)) |
| Transitions in preview | Live | CSS stand-in labeled “Simple fade” |
| MP4 assembly | Live | [`PostRenderJob`](/app/jobs/post_render_job.rb) — hold each frame, `xfade` fade, attach to [`PostRender`](/app/models/post_render.rb) |
| AI transitions (Kling / Runway) | Later | Extra transition types beside simple fade |

PNG: `GET /app/posts/:id.png?scene=overlay-10`  
MP4: render from the settings panel → `GET /app/post_renders/:id`

## Local run

```bash
bin/dev
# sign in as admin → Studio → Posts
# paste /app/media_bank/:id into a post’s source → Save → Render video
```

Ferrum needs Chrome/Chromium (same as Layers). ffmpeg on PATH for real MP4s (`RENDER_MEDIA=1` in tests). Tests mock ffmpeg unless that flag is set.

## Media bank

Seed / sync: `bin/rails media_bank:seed`, `media_bank:export`, `media_bank:import`. Browse/upload at `/app/media_bank` (group by shop, filter by tag); copy an item’s URL (`/app/media_bank/:id`) into a post’s source field. Tags include `barbershop`, `storefront`, plus shop slugs.
