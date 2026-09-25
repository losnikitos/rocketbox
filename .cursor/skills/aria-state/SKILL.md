---
name: aria-state
description: Use aria attributes when you need to apply styles conditionally, and manage state. E.g. aria-selected for selected tabs, pills etc, or aria-readonly for readonly state. Use it instead of applying tailwind classes conditionally.
---

Example 1: `aria-selected="true"` on selected element, apply styles like this: `aria-selected:bg-sky-200`. The attribute can be then edited in js `element.setAttribute('aria-selected', true|false)`.

Example 2: Set `class="group" aria-readonly="true"` on a parent element, and match state on child element with `group-aria-readonly:hidden`

Use appropriate aria element based on the semantics. Tailwind supports:
- aria-busy
- aria-checked
- aria-disabled
- aria-expanded
- aria-hidden
- aria-pressed
- aria-readonly
- aria-required
- aria-selected

