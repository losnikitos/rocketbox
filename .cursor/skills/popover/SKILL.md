---
name: popover
description: Popover in native html and tailwind, no js
---

Use native HTML popovers for small dropdown-like menus.

## Markup convention
1. Trigger element: use `popovertarget="<popover-id>"` and set `style="anchor-name: --<name>"`.
2. Popover element: matching `id="<popover-id>"`, boolean `popover`, and `style="position-anchor: --<name>"`.
3. Positioning: Tailwind arbitrary values with CSS anchor positioning, e.g. `top-[calc(anchor(bottom)+4px)]` and `left-[calc(anchor(left))]` (or `right-[...]`). Also use `inset-auto m-0` so UA popover centering does not win when the anchor is missing.

Do **not** rely on the popover invoker as an implicit CSS anchor alone. Without an explicit `anchor-name` / `position-anchor` pair, `anchor()` can resolve to `0` and the menu jumps to the top-left corner.

## Minimal example
```erb
<button popovertarget="my-menu" style="anchor-name: --my-menu">
  Trigger
</button>

<div id="my-menu" popover
     style="position-anchor: --my-menu"
     class="inset-auto m-0 top-[calc(anchor(bottom)+4px)] left-[calc(anchor(left))] ...">
  Popover content
</div>
```

## Examples in codebase
- `app/views/shared/admin_links/_menu.html.erb`
