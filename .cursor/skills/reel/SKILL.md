---
name: reel
description: Turn an Instagram reel into a scripted transformation type. Download it, find its cuts or beats with the notebook, extract its track, take its first frame as the type's cover, and write the `Reels::<Name>` class. Use when the user drops a reel link or mp4 and asks to analyze it, find its segments, cuts or beats, extract its sound, or add it as a transformation type.
---

# Reel → scripted transformation type

A scripted type is one folder, `reels/<slug>/`, autoloaded as `Reels::<Name>` ([reels.rb](/config/initializers/reels.rb)). How it renders is described in [scripted.rb](/app/models/transformation/scripted.rb) and [PROMPTS.md](/docs/PROMPTS.md). Read both first, and read the newest `reels/*/<slug>.rb` to copy its style.

```
reels/<slug>/
  <slug>.mp4    original reel (also previewed on the step's form)
  <slug>.wav    its track, laid under every render
  beats.csv     cut ends in seconds, read by Scripted#cuts
  beats.ipynb   the analysis, saved with its outputs
  segments/     one clip per cut, for checking only
  <slug>.rb     the class
app/assets/images/transformations/<slug>.jpg   cover: the reel's first frame, 400x600
```

## Steps

1. **Name it.** Use the user's name if they gave one. Otherwise name it after the track or the creator, and don't reuse a slug that's taken. The slug is snake_case (`black_eyed_peas` → `Reels::BlackEyedPeas`).

2. **Download** into a new folder. Drop query params like `?stkn=` from the URL. Tools live in `reels/.venv`, which is gitignored; `uvx yt-dlp` works too.
   ```bash
   mkdir -p reels/<slug> && cd reels/<slug>
   ../.venv/bin/yt-dlp -o "<slug>.%(ext)s" -f "bv*+ba/b" --merge-output-format mp4 "<reel url>"
   ffprobe -v error -show_entries stream=codec_type,width,height,r_frame_rate,duration -of compact <slug>.mp4
   ```
   Instagram rarely names the song (`yt-dlp -j --skip-download <url>` shows what metadata exists). Keep any audio page link the user gives (`instagram.com/reels/audio/<id>`).

3. **Pick the marks.** Probe scene-change scores first. A clear gap between real cuts and everything else tells you the `SCENE` threshold:
   ```bash
   ffmpeg -v error -i <slug>.mp4 -vf "select='gte(scene,0)',metadata=print:file=-" -an -f null - | paste - - \
     | sed -E 's/.*pts_time:([0-9.]+).*scene_score=([0-9.]+)/\1 \2/' | sort -k2 -nr | head -40
   ```
   Whip transitions, blur or a constant text overlay make scene detection weak. When that happens, look at a timestamped contact sheet instead (`fps=4,scale=180:-1,drawtext=text='%{pts\:flt}':…,tile=7x4`) and compare it with the beat grid. Valid `MARKS` values are:
   - `cuts`: the editor's own cuts (Welcome, Azzurro)
   - `beats[3::4]`: every bar, on the tempo grid (Black Eyed Peas, when the user wants N even segments)
   - `onsets`: every hit
   - a hand-made array, when the user names merges or splits

4. **Run the notebook.** Copy the newest `reels/*/beats.ipynb`, point `VIDEO` at the new mp4, set `MARKS` and `SCENE`, clear the outputs, then execute it in place. Running it writes `<slug>.wav`, `beats.csv` and `segments/`.
   ```bash
   cd reels/<slug> && ../.venv/bin/jupyter nbconvert --to notebook --execute --inplace beats.ipynb
   ```
   Edit the notebook JSON with `jq` or Python (set `outputs = []`, `execution_count = null`); don't hand-edit it. Leave the outputs saved so the user can open the plots.

5. **Check the cuts.** Build a sheet from each segment's first frame and show it to the user. Every tile should be a new shot: if one shot appears twice, it was split; if a tile holds two shots, a cut was missed.
   ```bash
   tmp=$(mktemp -d); for f in segments/*.mp4; do ffmpeg -v error -y -i $f -frames:v 1 -vf scale=180:-1 $tmp/$(basename $f .mp4).png; done
   ffmpeg -v error -y -pattern_type glob -i "$tmp/*.png" -vf "tile=9x4:padding=4" /tmp/<slug>_sheet.png
   ```

6. **Cover.** The reel's first frame, center-cropped to 2:3, becomes `Transformation::Type.cover`, which the Type picker shows. If the first frame is black or a fade, tell the user instead of quietly picking another frame.
   ```bash
   ffmpeg -y -loglevel error -i reels/<slug>/<slug>.mp4 -frames:v 1 \
     -vf "scale=400:600:force_original_aspect_ratio=increase,crop=400:600" -q:v 3 app/assets/images/transformations/<slug>.jpg
   ```

7. **Class** `reels/<slug>/<slug>.rb`, a subclass of `Transformation::Scripted`:
   - `label`, plus a `description` in the same voice as the others ("Cuts where the X reel cuts, under its track, a random input per cut, never the same one twice in a row.")
   - `source_url`: the reel or audio link, shown on the form. Note the other one in a comment.
   - `layer`: needed only if the reel has on-screen text. Reuse a layer from [layer.rb](/app/models/layer.rb) (`text`, `caption`, `welcome`). A new look needs a new `Layer::ALL` entry plus a template in `app/views/accounts/layers/templates/`; crop a full-resolution frame to match the font and position.
   - `steps`: how many text rows the form shows. 1 means one text over every cut; N means one row per cut.
   - Override `cuts` or `layer_values(i)` only when the reel's logic differs (see Welcome and Steps).

8. **Register** the class in `Transformation::Type.all` ([type.rb](/app/models/transformation/type.rb)), after the other `Reels::` entries.

9. **Test and document.** Add `"<slug>" => <video length>` to the track hash in [transformation_test.rb](/test/models/transformation_test.rb), next to `"doppler" => 9.6`. Add the slug to the Scripted list in [PROMPTS.md](/docs/PROMPTS.md). Then run:
   ```bash
   bin/rails test test/models/transformation_test.rb test/controllers/accounts/transformations_controller_test.rb
   ```

10. **Report** to the user: the segment count and timings, the contact sheet, the cover, the reel and audio links, and any guess you made (marks, layer, steps).
