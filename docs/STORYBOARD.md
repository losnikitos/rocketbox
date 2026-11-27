# Storyboard (Studio)

Admin tool for **Rocketbox’s own promo** ads (not customer SMM workflows). Configurable videos (source image + rules), shared overlays/CTA, simple-fade transitions — previewed scene-by-scene, then rendered to MP4.

## Where

Sidebar → **Studio**:

| Tool | Path | Notes |
|------|------|--------|
| Media bank | [`/app/media_bank`](/app/media_bank) | Tagged reference photos (`Folder.bank`); each item at `/app/media_bank/:id` |
| Storyboard | [`/app/storyboards`](/app/storyboards) | Scene preview, settings, PNG + MP4 export |

Open locally with an admin account (e.g. `?account=5` on prod). Example: http://localhost:3003/app/storyboards/guide-promo

## Settings (right panel)

Shared across all videos:

- **Transition** — only **Simple fade** for now (non-AI ffmpeg `xfade`; more types later)
- **Overlays** — rule number + text (e.g. #10 Keep the facade clear)
- **CTA** — text + href

Per video:

- **Source image** — public path (`/guides/…`) or Media bank item URL (`/app/media_bank/:id`)
- **Rules** — which shared overlays apply to that video

Add/remove videos, **Save settings**, then **Render video N**. When the job finishes, **Download** the MP4 from the same panel. Scene PNG export remains for still / overlay / CTA.

Film strip switches scenes for the selected video (`?video=0`).

## Guide promo defaults

Seeded settings for [`guide-promo`](/app/models/storyboard.rb) use the public barbershop compare set:

1. **v0** — before (`cluttered.jpg`)
2. **Overlay · rule #10** — “Keep the facade clear”
3. **Transition** — simple fade → clear facade
4. **v1** — `clean.jpg`
5. **Overlay · rule #12** — “Use warm light”
6. **Transition** — simple fade → warm
7. **v2** — `warm.jpg`
8. **CTA** — comment “guide” → `/guides/barbershop`

A media-bank-only video (source + rules, no after frames) stacks overlays on that source, then the shared CTA; fades run between those frames in the MP4.

## Rendering pipeline

| Stage | Status | How |
|-------|--------|-----|
| Still + overlay + CTA frames | Live | Ferrum HTML/Tailwind ([`Layer.screenshot`](/app/models/layer.rb)) |
| Transitions in preview | Live | CSS stand-in labeled “Simple fade” |
| MP4 assembly | Live | [`StoryboardRenderJob`](/app/jobs/storyboard_render_job.rb) — hold each frame, `xfade` fade, attach to [`StoryboardRender`](/app/models/storyboard_render.rb) |
| AI transitions (Kling / Runway) | Later | Extra transition types beside simple fade |

PNG: `GET /app/storyboards/:id.png?scene=overlay-10`  
MP4: render from the settings panel → `GET /app/storyboard_renders/:id`

## Local run

```bash
bin/dev
# sign in as admin → Studio → Storyboard
# paste /app/media_bank/:id into a video’s source → Save → Render video
```

Ferrum needs Chrome/Chromium (same as Layers). ffmpeg on PATH for real MP4s (`RENDER_MEDIA=1` in tests). Tests mock ffmpeg unless that flag is set.

## Media bank

Seed / sync: `bin/rails media_bank:seed`, `media_bank:export`, `media_bank:import`. Browse/upload at `/app/media_bank` (group by shop, filter by tag); copy an item’s URL (`/app/media_bank/:id`) into a video’s source field. Tags include `barbershop`, `storefront`, plus shop slugs.
