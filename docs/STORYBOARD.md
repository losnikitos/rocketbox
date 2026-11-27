# Storyboard (Studio)

Admin tool for **Rocketbox’s own promo** ads (not customer SMM workflows). Coded sequences of stills, rule overlays, video transitions, and a CTA — previewed scene-by-scene, then rendered.

## Where

Sidebar → **Studio**:

| Tool | Path | Notes |
|------|------|--------|
| Media bank | [`/admin/media_bank`](/admin/media_bank) | Dropbox-like tagged reference photos (`Folder.bank`) |
| Storyboard | [`/app/storyboards`](/app/storyboards) | Scene preview + PNG export for stills |

Open locally with an admin account (e.g. `?account=5` on prod). Example: http://localhost:3003/app/storyboards/guide-promo

## Guide promo sequence

Defined in code ([`Storyboard::GUIDE_PROMO`](/app/models/storyboard.rb)), using public barbershop compare images under `public/guides/barbershop/`:

1. **v0** — before (`cluttered.jpg`)
2. **Overlay · rule #10** — “Keep the facade clear” over v0
3. **Transition v0 → v1** — stub crossfade (cluttered → clean)
4. **v1** — clear facade (`clean.jpg`)
5. **Overlay · rule #12** — “Use warm light” over v1
6. **Transition v1 → v2** — stub (clean → warm)
7. **v2** — warm light (`warm.jpg`)
8. **CTA** — comment “guide” → `/guides/barbershop`

Switch scenes in the bottom film strip; settings sit in the right panel. Download PNG on still / overlay / CTA scenes.

## Rendering pipeline

| Stage | Status | How |
|-------|--------|-----|
| Still + overlay frames | Live | Ferrum HTML/Tailwind composition ([`Layer.screenshot`](/app/models/layer.rb)), same pattern as Layers |
| Video transitions | Stub | CSS crossfade preview; full path is `Transformation::GenerateVideo` (Kling / Runway first→last frame via RubyLLM) |
| Final assembly | Not yet | Concat stills + overlays + transition clips + CTA (ffmpeg), designed for a later job |

PNG export: `GET /app/storyboards/:id.png?scene=overlay-10` (admin session).

## Local run

```bash
bin/dev
# sign in as admin → Studio → Storyboard
```

Ferrum needs Chrome/Chromium (same as Layers PNG download). No extra secrets for stills.

### Secrets / APIs (video later)

Video transitions reuse the existing generation stack (`GenerationOptions` / RubyLLM animate). Credentials already used for customer video steps apply (OpenRouter / provider keys in Rails credentials). Nothing new is required for the still preview path.

## Media bank

Seed / sync: `bin/rails media_bank:seed`, `media_bank:export`, `media_bank:import` (see ActiveAdmin page). Tags include `barbershop`, `storefront`, plus shop slugs. Storyboard stills currently use the guide compare set; bank assets are the pool for later variants.
