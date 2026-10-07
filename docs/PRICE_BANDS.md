# Model price bands

Every enabled image or video model carries a rough price band: `price_band` on `ruby_llm_models`, 1–3, shown as £ / ££ / £££. It is set by hand in Active Admin ([admin](/app/admin/ruby_llm_models.rb), RubyLLM → Models → Edit).

The band sorts the model picker cheapest first, with unbanded models last ([GenerationOptions#models](/app/models/concerns/generation_options.rb)). It also draws the coins in the picker ([view](/app/views/shared/_generation_options.html.erb)). New records default to the first model, which is the cheapest.

## How to estimate

Compare providers on what one generation costs at **our defaults** (`IMAGE_DEFAULTS` / `VIDEO_DEFAULTS` in [GenerationOptions](/app/models/concerns/generation_options.rb)), taken from the providers' own pricing pages:

- **Image:** cost of one **2K** image at the **highest quality the app offers** (OpenAI: `high`). Output only.
- **Video:** price **per second at 720p**. Our default 8 s clip costs 8× that.

| Band | Image (per 2K image) | Video (per second, 720p) |
| --- | --- | --- |
| £ | under ~$0.04 | ~$0.05 |
| ££ | ~$0.04–0.11 | ~$0.10 |
| £££ | ~$0.12 and up | ~$0.40 |

Don't use the `pricing` column on the model row. It is per token, missing for many models, and can't be compared across providers.

### Sources

- **Gemini (images and Veo):** the [pricing page](https://ai.google.dev/gemini-api/docs/pricing) lists a per-image price for each resolution and a per-second price for video. Read the 2K figure directly.
- **OpenAI:** token rates are identical across `gpt-image-2` and `gpt-image-2.5-*`, so they say nothing about cost per image. Use the token calculator in the [image generation guide](https://developers.openai.com/api/docs/guides/image-generation) at our 9:16 2K size (1440×2560). Cost per image is output tokens × $30 per million. For example, `high` is 7,370 tokens ($0.221) on `gpt-image-2` and 1,843 tokens ($0.055) on 2.5.
- **Token-billed video (Gemini Omni):** use the provider's per-second equivalent at 720p.

### Reference points (Oct 2026)

| Model | Basis | Band |
| --- | --- | --- |
| `gemini-3.1-flash-lite-image` | $0.034 / image | £ |
| `gemini-nano-banana-2.1` | $0.050 / 2K image | ££ |
| `gpt-image-2.5-flare`, `-sunburst` | $0.055 / 2K high | ££ |
| `gemini-3.1-flash-image` | $0.101 / 2K image | ££ |
| `gemini-3-pro-image` | $0.134 / 2K image | £££ |
| `gpt-image-2` | $0.221 / 2K high | £££ |
| `veo-3.1-lite-generate-preview` | $0.05 / s | £ |
| `veo-3.1-fast-generate-preview`, `gemini-omni-1.1-flash` | $0.10 / s | ££ |
| `veo-3.1-generate-preview` | $0.40 / s | £££ |

## Known gaps

- **Reference photos are not counted.** Edits and recipe runs also pay input tokens. These are cheap on Gemini, but `gpt-image-2` always reads input at high fidelity, which makes it even pricier than its band shows.
- **Lower quality settings are cheaper.** At OpenAI `medium` or `low`, the 2.5 models cost less than flash-lite. The band reflects the worst case.
- **Gemini thinking/text output** is billed too. It is small and varies per call.
- **Real cost** of every call is in RubyLLM's usage table ([admin](/app/admin/ruby_llm_usages.rb), RubyLLM → Usages). Check it against the band once a model has real traffic.

## Enabling a new model

Before enabling a model fetched from a provider API, check two things:

1. **Modalities.** These are often empty for API-only models, and then the app treats the model as chat and hides it from the picker. Copy them from a sibling model. A models refresh keeps hand-set modalities ([initializer](/config/initializers/ruby_llm.rb)).
2. **Request routing.** Check that ruby_llm sends the model to an endpoint it supports. For example, Gemini image IDs without `-image` needed a patch in the [initializer](/config/initializers/ruby_llm.rb).
