# Post frames (agents)

Studio Posts ([PRESET.md](./PRESET.md)) need one generated still per selected guide rule (`PostFrame`: position `1` = v1, `2` = v2, …). Agents fill missing frames from the post's Markdown.

## Read the post first

Same path plus `.md`. No auth; `account` does not matter. Example:

```bash
curl -s "https://dev.rocketbox.plus/app/posts/2.md"
```

Use `http://localhost:3003` when the tunnel is down. The page is [`show.md.erb`](/app/views/accounts/posts/show.md.erb).

## Generate (one rule at a time)

For each **missing** frame in order:

1. Export the reference still to a local path (v0 = source media bank file; later = previous `PostFrame`):

```bash
bin/rails runner '
post = Post.find(POST_ID)
ref = POSITION == 1 ? post.source_media : post.frame_at(POSITION - 1)
path = Rails.root.join("tmp", "post#{post.id}-ref-v#{POSITION - 1}.jpg")
File.binwrite(path, ref.file.download)
puts path
'
```

2. Call Cursor **GenerateImage** with:
   - `description` = that rule's **Image prompt** from the Markdown (the `GuideRule#prompt`)
   - `reference_image_paths` = `[that tmp path]` (optionally also the guide's compare "do" image if helpful)
   - `aspect_ratio` matching the source (storefront photos are usually `4:3`)
   - `filename` like `post{POST_ID}-v{N}-rule{NUMBER}.png`

3. Attach the generated file as the frame:

```bash
bin/rails runner '
post = Post.find(POST_ID)
path = Rails.root.join("PATH_TO_GENERATED.jpg")
frame = post.frames.find_or_initialize_by(position: N)
frame.rule_number = RULE_NUMBER
frame.save!
frame.file.attach(io: File.open(path), filename: path.basename.to_s, content_type: "image/jpeg")
puts "v#{frame.position} attached=#{frame.file.attached?}"
'
```

4. Re-curl the `.md` (or check Studio) before the next rule — the next reference is the frame you just attached.

Do not invent prompts when `GuideRule#prompt` is set. Do not re-generate attached frames unless the human asks. Public `/guides` never shows these prompts; Studio Guides does.
