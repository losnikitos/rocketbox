# Rocketbox — Marketing Site UI Kit

A high-fidelity recreation of the Rocketbox marketing site (the place where books, lessons, and membership are sold).

Open `index.html` in a browser. The kit is a single click-through prototype with five top-level screens accessible via the nav:

1. **Home** — hero + featured book + catalogue strip + membership pitch
2. **Catalogue** — full grid of books, filterable by topic
3. **Product** — single book page with hero cover, blurb, contents callout block, buy panel
4. **Membership** — pricing + what's inside
5. **About** — short manifesto + the two founders

Components live in `components.jsx`. They are intentionally small and cosmetic — no real routing, no real auth, no real cart. Click "Buy" and you'll see a fake confirmation toast.

## Components covered
- `<TopBar>` — sticky 56px header with logo, nav, sign-in
- `<Hero>` — display headline + book cover
- `<BookCard>` — catalogue tile
- `<BookRow>` — list-view catalogue row
- `<ContentsBlock>` — the signal-colour callout grid from book contents pages
- `<BuyPanel>` — sticky price + buy CTA
- `<MembershipCard>` — pricing card with feature list
- `<FounderCard>` — rectangular portrait + bio
- `<Footer>` — two-row site footer
- `<Toast>` — bottom-left ephemeral confirmation
