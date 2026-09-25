# Icons

UI icons are [Heroicons](https://heroicons.com) via the [`heroicons`](https://github.com/bharget/heroicons) gem (`heroicon` helper in ERB).

## Defaults

Call `heroicon "name"` — do not set variant or size. Override only when the surrounding UI needs it.

Next to a label, wrap icon + text in `inline-flex items-center gap-1.5` (see [page header](/app/views/shared/_page_header.html.erb)). Mark purely decorative icons `aria-hidden: true` when the parent already has an accessible name ([flashes](/app/views/shared/_flashes.html.erb)).
