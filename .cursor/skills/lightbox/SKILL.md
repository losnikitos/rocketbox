---
name: lightbox
description: Full-screen image lightbox with native HTML popover and Tailwind, no JS. Use when a thumbnail should open a larger view on click — image previews, galleries, zoom, "view full size".
---

A thumbnail button opens a full-viewport `popover`; the enlarged image is wrapped in a hide button, so clicking anywhere closes it. Esc and light-dismiss come free from the browser.

## Markup convention
1. Trigger: `<button type="button" popovertarget="<id>">` wrapping the thumbnail, with `aria-label` and `cursor-zoom-in`.
2. Popover: `<div id="<id>" popover class="size-full bg-black/90 p-4">`. `size-full` overrides the UA fit-content sizing; the UA `inset: 0` already pins it to the viewport. No anchor positioning needed (unlike the `popover` skill's menus).
3. Close: fill the popover with `<button type="button" popovertarget="<id>" popovertargetaction="hide" aria-label="Close">`, `flex size-full items-center justify-center cursor-zoom-out`.
4. Image: `max-h-full max-w-full` so it fits the viewport without cropping.
5. IDs must be unique per item, e.g. `example-<%= record.id %>`.

Images only — videos keep their own controls inline; a full-screen click-to-close button would swallow them.

## Minimal example
```erb
<button type="button" popovertarget="photo-<%= photo.id %>" aria-label="View <%= photo.filename %>" class="block w-full cursor-zoom-in">
  <%= image_tag url_for(photo), alt: photo.filename.to_s, class: "aspect-2/3 w-full rounded-lg object-cover" %>
</button>
<div id="photo-<%= photo.id %>" popover class="size-full bg-black/90 p-4">
  <button type="button" popovertarget="photo-<%= photo.id %>" popovertargetaction="hide" aria-label="Close" class="flex size-full cursor-zoom-out items-center justify-center">
    <%= image_tag url_for(photo), alt: photo.filename.to_s, class: "max-h-full max-w-full" %>
  </button>
</div>
```

## Examples in codebase
- `app/views/accounts/recipes/_form.html.erb` (recipe examples grid)
- `app/views/accounts/library/show.html.erb` (hero media)
