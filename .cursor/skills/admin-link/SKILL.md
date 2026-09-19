---
name: admin-link
description: >-
  Admin context-menu (popover) for any record. Use when adding admin shortcuts
  (Avo, etc.) in customer UI.
---

# Admin links (context menu)

Admin actions are an ellipsis button that opens a native HTML popover menu. Do **not** render bare green pencil icons, “Admin” pills, or standalone Avo links.

All entity menus live under [`app/views/shared/admin_links/`](/app/views/shared/admin_links/).

## Shared primitives

| Partial | Role |
|---------|------|
| [`_menu.html.erb`](/app/views/shared/admin_links/_menu.html.erb) | Ellipsis trigger + popover shell (`popover_id`, `align`, optional `trigger_class`). Use as a **layout** with a block. |
| [`_item.html.erb`](/app/views/shared/admin_links/_item.html.erb) | One menu row (`path`, `label`, `icon`, `chip`). |

Chip conventions:
- Avo: `bg-signal-green` + `pencil`

Follow the [popover](../popover/SKILL.md) skill for positioning. The shared `_menu` sets an explicit `anchor-name` / `position-anchor` pair — do not remove those; without them `anchor()` can resolve to `0` and the menu jumps to the top-left.

## By entity

| Entity | Partial | Typical items |
|--------|---------|-----------------|
| Library media | [`_library_media`](/app/views/shared/admin_links/_library_media.html.erb) | Avo, Remove |

## Usage

```erb
<%= render 'shared/admin_links/library_media', library_media: media %>
```

Optional locals (most entities):
- `links:` hash to toggle items (keys vary; all default `true`)

Popover ids are **always unique** via [`admin_link_id_suffix`](/app/helpers/admin_links_helper.rb) (called from [`_menu`](/app/views/shared/admin_links/_menu.html.erb)). Do **not** pass a manual `suffix:` — the same record can be rendered many times on one page without clashes.

## Adding a new entity

1. Add `app/views/shared/admin_links/_<entity>.html.erb` using `_menu` + `_item`.
2. Gate on `Current.user&.admin?` (or the entity policy).
3. Replace any bare green pencil / Admin pill with `render 'shared/admin_links/<entity>', …`.
4. Document the partial in the table above.
