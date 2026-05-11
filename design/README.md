# Rocketbox Design System

**Rocketbox** publishes online books and short-format lessons for small and medium-sized businesses. The catalogue covers customer service, retention, support operations, and the practical operator stuff that nobody teaches you when you open your second location.

The brand is built on the conviction that the people who run small businesses are smart, busy, and tired of fluff. Materials are short. Examples are real. The voice is direct.

---

## What's in this folder

| File / folder | What it's for |
|---|---|
| `README.md` | This document. Brand context, content fundamentals, visual foundations, iconography. |
| `colors_and_type.css` | CSS variables for colors, typography scale, spacing, radii, shadows. Drop into any prototype. |
| `fonts/` | Web fonts (or Google Fonts links). |
| `assets/` | Logos, icon files, illustrations, generic product imagery. |
| `preview/` | Specimen cards that populate the Design System tab. |
| `ui_kits/site/` | High-fidelity recreation of the marketing site (hero, catalogue, product page, footer). |
| `ui_kits/reader/` | High-fidelity recreation of the in-product reader (book index, lesson page, video lesson). |
| `SKILL.md` | Agent-skill entry point. |

There is no slide template attached, so `slides/` is intentionally absent.

---

## Source materials

The visual direction is referenced from these uploaded screenshots (in `uploads/`):

- `ru_complex-designer.png`, `ru_complex-designer-summary.png` — book product page + book contents page
- `ru_how-to-design-with-code.png` — course page
- `ru_planetarium.png` — community membership page
- `ru_projects.png` — projects/portfolio index
- `ru_this-is-beautiful.png` — book product page (compact)
- `ru_what-must-be-in-the-brandbook.png` — webinar page

The screenshots are from a Russian design bureau ("Интуиция" / Intuition by Eugene Arutyunov). They are visual reference only — Rocketbox is an unrelated English-language brand serving SMBs. Tone, layout density, and color usage are inspired by these references; copy, products, and audience are not.

No Figma or codebase was attached. If one becomes available, re-import and re-run this skill.

---

## The products

Rocketbox sells three product types:

1. **Books** — short, focused, browser-only e-books. ~70 short chapters or essays. Bought once, read in the reader.
2. **Lessons** — single-topic short videos or text lessons. Often bundled into a "course" of 10–20.
3. **Membership** — recurring access to live monthly Q&A clinics, a Slack-style community, and the full back-catalogue.

The marketing site sells all three. The product (the "reader") delivers them.

---

## CONTENT FUNDAMENTALS

The voice is **direct, intelligent, and operator-grade**. We talk like a colleague who has actually run the thing, not like a marketer.

### Voice rules

- **"You" and "we", never "users" or "customers".** "You" is the reader. "We" is Rocketbox. The third party is "the customer" — never "the user".
- **Sentence case for everything.** Headings, buttons, navigation. Title Case looks corporate; we don't use it. Brand name "Rocketbox" is always capitalised; product names are sentence case.
- **No exclamation marks.** A claim that needs an exclamation mark is a weak claim.
- **No em-dashes for drama.** Plain commas and full stops. If you need a pause, use a comma. Em-dash only for parenthetical asides.
- **Short paragraphs.** Two to four sentences. The reader is scanning.
- **Numbers as numerals** from 2 upward. "2 lessons", "70 chapters". Spell out "one".
- **Lead with the verb.** "Improve your refund flow" not "How to improve your refund flow". CTAs are imperative.
- **Concrete > abstract.** "Cut your refund window from 14 days to 3" beats "Streamline returns".
- **Price is shown plainly.** "$24" not "Just $24!" or "$24.00".

### What we don't do

- No emoji in product copy. (Acceptable in the in-reader chat / community where it is user-generated.)
- No "unlock", "elevate", "supercharge", "game-changing", "revolutionary".
- No filler intros ("In today's fast-paced…"). Cut the first paragraph if it's throat-clearing.
- No fake urgency ("Only 3 seats left"). If a cohort has 8 seats, say 8.
- No testimonials with last-name-initial-only attribution. Real names, real businesses, or omit.

### Example copy

**Hero headline** — "Run a better small business. One short book at a time."

**Book card** — "Refunds & returns / 64 pages / $24 / How to cut refund time without giving away the store."

**CTA** — "Buy — $24" / "Add to library" / "Start the lesson"

**Empty state** — "No lessons here yet. Start with the basics: 'Greeting the customer'."

**Error** — "Card declined. Try again, or use a different card."

**Confirmation** — "Done. Check your email."

### Headline style

Headlines do the heavy lifting. They are big, set tight, and use sentence-case. Two-line headlines are preferred over one-line; line breaks are deliberate. Example:

> Run a better
> small business.
> One short book at a time.

---

## VISUAL FOUNDATIONS

Rocketbox is **dark-first**, **type-led**, and uses **flat saturated colour as a punctuation mark**, not as a wash.

### Mood in one sentence

A serious operator's manual designed by someone with taste — confident type, generous black, the occasional shock of pure colour where it earns its place.

### Colour

- **Background is near-black** (`--ink-900: #0E0E0F`), never pure `#000`. Pure black looks cheap on OLED and absorbs all hierarchy.
- **Foreground is warm white** (`--paper: #F4F1EA`), slightly off-white, set against ink-900. White type on near-black is the default.
- **One brand accent: Rocket Blue** (`--rocket: #2D6BFF`). Used for primary CTAs, links, focus rings. Nothing else.
- **Four signal colours**, used as flat fill blocks in callouts and tags, never as background washes:
  - `--signal-green: #34C26B` — wins, success, "this works"
  - `--signal-red: #FF4D3D` — warning, "don't do this"
  - `--signal-yellow: #FFD400` — highlight, important
  - `--signal-pink: #FFD1D1` — soft highlight, side-notes
- **Light mode exists but is secondary.** Paper background (`--paper-50: #FAF7F1`), ink-900 text. The reader product offers it. Marketing is always dark.

Gradients are not part of the system. No glows. No glass.

### Typography

- **Display & headings**: `Manrope` (Google Fonts). Weights 700 and 800. Used at 48–96px on web, set tight at `letter-spacing: -0.02em` and `line-height: 1.02`. Sentence-case.
- **Body & UI**: `Inter` (Google Fonts). Weights 400, 500, 600. Body copy is 17px on web, 19px in the reader. Line-height 1.55.
- **Mono**: `JetBrains Mono` (Google Fonts). Used only for prices, page numbers, and code samples. 14–15px.

**Substitution note.** The Russian-language references appear to use Onest or a custom Manrope-derivative. We've substituted **Manrope + Inter** from Google Fonts as the closest accessible match. If brand fonts become available, drop the `.woff2` files into `fonts/` and update `colors_and_type.css`.

### Spacing & rhythm

8px base grid. Tokens: `--s-1` (4px), `--s-2` (8px), `--s-3` (12px), `--s-4` (16px), `--s-5` (24px), `--s-6` (32px), `--s-8` (48px), `--s-10` (64px), `--s-12` (96px). Cards have 32px inner padding on desktop. Section vertical rhythm is 96px between sections.

### Radii

The system uses **two radii** and that's it.

- `--r-card: 18px` — books, cards, image tiles, hero blocks
- `--r-control: 10px` — buttons, inputs, chips

No 24px+ rounding. No fully-round pills except in one place: the price chip on book covers.

### Borders

Default border is `1px solid rgba(244, 241, 234, 0.10)` on dark — a faint ivory line. On paper it's `1px solid rgba(14, 14, 15, 0.10)`. Borders are used to separate, never to decorate.

### Shadows

Two elevations, both subtle:

- `--shadow-card`: `0 1px 0 rgba(255,255,255,0.04) inset, 0 12px 32px rgba(0,0,0,0.35)` — books and lifted cards
- `--shadow-pop`: `0 24px 64px rgba(0,0,0,0.55)` — modals and focused-state book covers

Buttons do not carry shadows. The blue CTA stands on colour alone.

### Backgrounds & textures

- The marketing site is solid `--ink-900`.
- The reader is solid `--paper-50` in light mode, `--ink-900` in dark.
- Section dividers are 1px hairline rules, not background colour changes.
- **No** repeating patterns. **No** noise. **No** texture overlays. **No** gradients.
- Hero sections can carry a single large book cover as the visual centrepiece — that's the texture.

### Imagery

- Book covers are first-class objects. They sit on the page at large scale and carry their own colour. They get a single `--shadow-card` to feel like physical books.
- Author / instructor photos are **rectangular** with `--r-card` rounding. Never circular. Set warm and not over-processed; slightly muted, slightly cinematic, no aggressive vignettes.
- Generic stock-style photography is avoided. If we need imagery, we use product covers, photos of real instructors, or no image at all.

### Animation

- **Default duration**: 160ms. **Default easing**: `cubic-bezier(0.2, 0, 0, 1)` — soft-out, quick-in. Stored as `--ease`.
- **Hover**: opacity 0.85 on links and ghost buttons; the blue CTA lightens by 6% (to `--rocket-hover: #3F7BFF`).
- **Press**: 98% scale + 80ms duration. Subtle.
- **Focus**: 2px ring of `--rocket` at 50% alpha, offset 2px.
- **Page transitions**: none. No fade-ins on scroll. No parallax. We respect the reader's attention.

### Callouts (signal colour usage)

The four signal colours appear as **flat-filled side-by-side blocks** in book contents pages, comparison tables, and webinar pages — exactly as the references use them. Each block is `padding: 12px 16px`, `border-radius: 0`, full saturated fill, and contains 1–3 lines of text. They are NOT used as section backgrounds, button colours, or icon tints.

### Transparency & blur

We use neither. If an overlay is needed, it is a solid `rgba(14,14,15,0.85)` scrim. No backdrop-filter blur.

### Layout

- Marketing pages use a **12-column 1280px** desktop grid, 32px gutters, 80px outer margin.
- The reader uses a **single-column 720px max-width** measure for prose.
- A **persistent top bar** of 56px sits on the marketing site (logo left, nav centre, "Sign in" right).
- The marketing footer is two rows: links + small print. No newsletter form on the homepage.

---

## ICONOGRAPHY

Rocketbox uses **Lucide icons** ([lucide.dev](https://lucide.dev)), CDN-served. Lucide's 1.5px stroke, rounded line-caps, and consistent 24px grid match the brand's quiet, utility-first tone. Icons are **always monochromatic**, rendered in `currentColor`, never tinted with brand colour for decoration.

**Substitution note.** No icon set was attached with the brand reference, so Lucide is a substitution for an unknown original. If a Rocketbox icon set exists, drop the SVGs into `assets/icons/` and remove the Lucide link.

### Rules

- **Default stroke**: 1.5px. **Default size**: 20px in UI, 24px in lists, 16px inline.
- **Alignment**: icons sit on the text baseline, never above or below.
- **Pairing**: icons appear to the left of labels with an 8px gap, never floating alone in nav (always with a label until the design proves otherwise).
- **No icon backgrounds.** No rounded squares behind icons. No coloured circular badges. The icon stands on its own.
- **No emoji** in any product surface. **No unicode glyph icons** (no ★ ☆ → unless used as actual content, e.g. in user reviews).

### The logo

The Rocketbox wordmark is set in Manrope ExtraBold, tracking `-0.03em`, with a small filled square dot replacing the dot above the "i" — a tiny visual flag that this is a publisher of small, contained things (boxes). See `assets/logo-wordmark.svg` for the master.

The square-mark version (`assets/logo-mark.svg`) is a filled rounded square containing a single stylized rocket trail glyph — used as the app icon and favicon only.

---

## Index

- Foundations → `colors_and_type.css`, `preview/`
- Brand assets → `assets/`
- Product surfaces → `ui_kits/site/index.html`, `ui_kits/reader/index.html`
- Agent skill entry point → `SKILL.md`
