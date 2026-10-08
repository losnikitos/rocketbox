---
name: admin-link
description: >-
  Admin context-menu (popover) for any record. Use when adding admin shortcuts
  (Active Admin, etc.) in customer UI.
---

# Admin links (context menu)

Admin actions are an ellipsis button that opens a native HTML popover menu. Do **not** render bare green pencil icons, “Admin” pills, or standalone admin links.

All entity menus live under [`app/views/shared/admin_links/`](/app/views/shared/admin_links/).

## Shared primitives

| Partial | Role |
|---------|------|
| [`_menu.html.erb`](/app/views/shared/admin_links/_menu.html.erb) | Ellipsis trigger + popover shell (`popover_id`, `align`, optional `trigger_class`). Use as a **layout** with a block. |
| [`_item.html.erb`](/app/views/shared/admin_links/_item.html.erb) | One menu row (`path`, `label`, `icon`, `chip`). |

Chip conventions:
- Admin: `bg-signal-green` + `cog`
- Remove: `bg-signal-red` + `trash`

Follow the [popover](../popover/SKILL.md) skill for positioning. The shared `_menu` sets an explicit `anchor-name` / `position-anchor` pair — do not remove those; without them `anchor()` can resolve to `0` and the menu jumps to the top-left.

## By entity

| Entity | Partial | Typical items |
|--------|---------|-----------------|
| Library media | [`_library_media`](/app/views/shared/admin_links/_library_media.html.erb) | Move to (opt-in submenu), Admin, Remove |
| Folder | [`_folder`](/app/views/shared/admin_links/_folder.html.erb) | Rename (submenu), Color (submenu), Admin, Delete |
| SMM post | [`_smm_post`](/app/views/shared/admin_links/_smm_post.html.erb) | Admin, Remove |
| Review | [`_review`](/app/views/shared/admin_links/_review.html.erb) | Admin, Remove |
| Recipe | [`_recipe`](/app/views/shared/admin_links/_recipe.html.erb) | Admin, Remove |
| Transformation | [`_transformation`](/app/views/shared/admin_links/_transformation.html.erb) | Admin, Delete |
| Transformation run | [`_transformation_run`](/app/views/shared/admin_links/_transformation_run.html.erb) | Admin |
| Workflow | [`_workflow`](/app/views/shared/admin_links/_workflow.html.erb) | Admin |
| Workflow run | [`_workflow_run`](/app/views/shared/admin_links/_workflow_run.html.erb) | Admin |
| Tags (library tabs) | [`_tags`](/app/views/shared/admin_links/_tags.html.erb) | Tags |

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
