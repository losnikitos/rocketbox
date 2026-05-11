# Rocketbox — Reader UI Kit

A high-fidelity recreation of the in-product reader — the surface a customer sees after they buy. Light-mode by default (paper background, ink text), with a one-tap dark toggle.

Open `index.html`. The kit shows three click-through screens:

1. **Library** — the customer's owned books and lessons, with progress indicators
2. **Book reader** — full prose page with table-of-contents drawer, footnotes, and the four-block decision card
3. **Lesson player** — short video lesson with chapter list and notes

## Components covered
- `<ReaderShell>` — top bar with library / search / theme toggle
- `<LibraryGrid>` — owned-book grid with progress bars
- `<TOCDrawer>` — slide-in chapter list
- `<ChapterPage>` — long-form prose with reader typography (19px Inter, 720px measure)
- `<DecisionCard>` — the four-block signal callout that ends each chapter
- `<LessonPlayer>` — video frame placeholder + transcript + chapter ticks
- `<NoteRail>` — right-side reader's personal notes
