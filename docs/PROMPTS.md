# Prompts

Content prompts are `Prompt` rows ([prompt.rb](/app/models/prompt.rb)), edited at `/app/prompts`. Each has a `body`, example media, a media type it suits, and whether it makes an image or a video. A generation sends the prompt's `body` plus the optional `extra_prompt` to a single AI call (`Generation#run!`).

Service prompts are constants in the code that uses them:

| Constant | Used for |
|----------|----------|
| `Crawl::DEFAULT_DATA_INSTRUCTION` | Default data instruction for a crawl |
| `ExtractBusinessCard::INFO_PROMPT` / `LOGO_PROMPT` | Reading a business card |
| `ImproveLibraryMedia::PROMPT` | Improving a library image with AI |
