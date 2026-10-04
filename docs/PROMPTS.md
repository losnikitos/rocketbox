# Prompts

Content prompts are `Prompt` rows ([prompt.rb](/app/models/prompt.rb)), edited at `/app/prompts`. Each has a `body`, example media, a media type it suits, and whether it makes an image or a video. A generation sends the prompt's `body` plus the optional `extra_prompt` to a single AI call (`Generation#run!`).

Recipes are the next step: `Recipe` rows ([recipe.rb](/app/models/recipe.rb)), edited at `/app/recipes`, compose several photobank photos into one image in the Ready library folder. Each has a `body` and an ordered list of media types, one per photo slot. Using a recipe means picking one photobank photo per slot; that creates a `RecipeRun` ([recipe_run.rb](/app/models/recipe_run.rb)) with the picked photos in `source_media_ids` and an empty Ready media, and `RecipeRun#run!` sends all of the photos with the body to a single image call and attaches the result to that media. The run keeps the prompt as sent, the cost and any error; the Ready media's page shows them.

Prompts and recipes both carry default AI options — model, aspect ratio, size, quality (duration for video) — in an `options` column ([generation_options.rb](/app/models/concerns/generation_options.rb)). A generation or recipe run starts from them, and the user can override any of them on the generate screen; options the picked model doesn't offer fall back to the defaults.

Styles are `Style` rows ([style.rb](/app/models/style.rb)), edited at `/app/styles`: a name, a `body` with visual cues (lighting, camera, colour, mood) and example images. A style is one more recipe option (`options["style"]`, a style id), so a recipe picks a default style and a recipe run can override it or choose "No style". Prompts and generations take no style. Its body is appended after the recipe body and is never sent to the provider as an option. The initial set was imported from tadaaa's shooting styles: `db/styles.yml` holds names, bodies and public photo URLs, and `bin/rails styles:import` ([styles.rake](/lib/tasks/styles.rake)) upserts them by name.

Shots are `Shot` rows ([shot.rb](/app/models/shot.rb)), edited at `/app/shots` with a tab per `group`. Each one is a scene to shoot (e.g. "Empty Chair"), made of a name, a `body` and example images. A recipe can take a shot by naming a group in `shot_group`. Using that recipe means picking one shot from the group (a random one is preselected); the run keeps it as `shot_id`, and its body goes between the recipe body and the style body. Examples are for browsing only. The initial "Daily" set of barbershop scenes lives in `db/shots.yml`, and `bin/rails shots:import` ([shots.rake](/lib/tasks/shots.rake)) upserts it by name.

Service prompts are constants in the code that uses them:

| Constant | Used for |
|----------|----------|
| `Crawl::DEFAULT_DATA_INSTRUCTION` | Default data instruction for a crawl |
| `ExtractBusinessCard::INFO_PROMPT` / `LOGO_PROMPT` | Reading a business card |
| `ImproveLibraryMedia::PROMPT` | Improving a library image with AI |
