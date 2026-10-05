# Prompts

Content prompts are `Recipe` rows ([recipe.rb](/app/models/recipe.rb)), edited at `/app/recipes` with a tab per input folder. Each has a `body`, example media, whether it makes an image or a video (`kind`), an ordered list of inputs, and an output folder. Each input is a library folder plus a tag (`inputs`, e.g. `[{ "collection" => "inbox", "tag_id" => 3 }]`) and may repeat (two staff photos); a video recipe takes exactly one. Results land in `output_collection` (Photobank or Ready) with the first input's tag. The pipeline uses recipes twice: Inbox recipes polish one owner photo into the Photobank, Photobank recipes compose several photos into a Ready image.

Running a recipe means picking one library media per input at `/app/recipes/:id/runs/new` (`media_ids[i]` preselects input `i`; a media page's "Apply recipe" links there). That creates a `RecipeRun` ([recipe_run.rb](/app/models/recipe_run.rb)) with the picked media as ordered `RecipeRunInput` rows and an empty result media, and `RecipeRun#run!` sends the media with the body (plus shot, style and the optional `extra_prompt`) to a single AI call and attaches the result to that media. The run keeps the prompt as sent, the cost and any error; the result media's page shows them. A run without a recipe records a version the owner dropped onto a media themselves; its input is the version's source.

Recipes carry default AI options — model, aspect ratio, size, quality (duration for video), style — in an `options` column ([generation_options.rb](/app/models/concerns/generation_options.rb)). A run starts from them, and the user can override any of them on the run screen; options the picked model doesn't offer fall back to the defaults.

Styles are `Style` rows ([style.rb](/app/models/style.rb)), edited at `/app/styles`: a name, a `body` with visual cues (lighting, camera, colour, mood) and example images. A style is one more recipe option (`options["style"]`, a style id), so a recipe picks a default style and a run can override it or choose "No style". Its body is appended after the recipe body and is never sent to the provider as an option. The initial set was imported from tadaaa's shooting styles: `db/styles.yml` holds names, bodies and public photo URLs, and `bin/rails styles:import` ([styles.rake](/lib/tasks/styles.rake)) upserts them by name.

Shots are `Shot` rows ([shot.rb](/app/models/shot.rb)), edited at `/app/shots` with a tab per `group`. Each one is a scene to shoot (e.g. "Empty Chair"), made of a name, a `body` and example images. A recipe can take a shot by naming a group in `shot_group`. Running that recipe means picking one shot from the group (a random one is preselected); the run keeps it as `shot_id`, and its body goes between the recipe body and the style body. Examples are for browsing only. The initial "Daily" set of barbershop scenes lives in `db/shots.yml`, and `bin/rails shots:import` ([shots.rake](/lib/tasks/shots.rake)) upserts it by name.

Service prompts are constants in the code that uses them:

| Constant | Used for |
|----------|----------|
| `Crawl::DEFAULT_DATA_INSTRUCTION` | Default data instruction for a crawl |
| `ExtractBusinessCard::INFO_PROMPT` / `LOGO_PROMPT` | Reading a business card |
| `ImproveLibraryMedia::PROMPT` | Improving a library image with AI |
