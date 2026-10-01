# Prompts

Content prompts are `Prompt` rows ([prompt.rb](/app/models/prompt.rb)), edited at `/app/prompts`. Each has a `body`, example media, a media type it suits, and whether it makes an image or a video. A generation sends the prompt's `body` plus the optional `extra_prompt` to a single AI call (`Generation#run!`).

Recipes are the next step: `Recipe` rows ([recipe.rb](/app/models/recipe.rb)), edited at `/app/recipes`, compose several photobank photos into one post. Each has a `body`, an output `format` (post, story, reel) and an ordered list of media types, one per photo slot. Using a recipe means picking one photobank photo per slot; that creates an `SmmPost` (with `recipe_id`) whose media items are the picked photos, and `SmmPost#generate!` sends all of them with the body to a single image call and attaches the result as the post's only slide. The model is the first enabled image model; the aspect ratio follows the format. Reels come out as a still image, which Instagram won't publish as a reel.

Service prompts are constants in the code that uses them:

| Constant | Used for |
|----------|----------|
| `Crawl::DEFAULT_DATA_INSTRUCTION` | Default data instruction for a crawl |
| `ExtractBusinessCard::INFO_PROMPT` / `LOGO_PROMPT` | Reading a business card |
| `ImproveLibraryMedia::PROMPT` | Improving a library image with AI |
