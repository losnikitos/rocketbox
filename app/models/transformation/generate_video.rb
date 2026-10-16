# frozen_string_literal: true

# A video animating its source photos.
class Transformation::GenerateVideo < Transformation::Generation
  def self.label = "Video"

  def self.video? = true

  def file
    first, last = images.first, (images.one? ? nil : images.last)
    args = ai_args
    with, provider_options = frame_args(first, last, args[:provider], args[:provider_options].to_h)
    result = RubyLLM.animate(run.prompt_text, with:, **args, provider_options:)
    attachment(result.to_blob, "mp4", "video/mp4")
  end

  private

    # ruby_llm 2.1 still only puts `with:` on image/video for Gemini and xAI; first+last go through
    # provider_options. Gemini deep_merges replace arrays, so the full instance is sent there.
    # ponytail: middles dropped when >2 images; referenceImages / reference_images when we need that mode.
    def frame_args(first, last, provider, provider_options)
      return [ [ first ], provider_options ] unless last

      case provider
      when :xai
        [ [ first ], provider_options.merge(last_frame: { url: llm_attachment(last).url_or_data_uri }) ]
      when :gemini
        [ nil, provider_options.merge(instances: [ {
          prompt: run.prompt_text,
          image: veo_image(first),
          lastFrame: veo_image(last)
        } ]) ]
      else
        [ [ first, last ], provider_options ]
      end
    end

    def llm_attachment(blob) = RubyLLM::Attachment.new(blob)

    def veo_image(blob)
      image = llm_attachment(blob)
      { bytesBase64Encoded: image.encoded, mimeType: image.mime_type }
    end
end
