# frozen_string_literal: true

# A video animating its source photos: Start (first frame), optional End (last frame), optional Refs, optional prompts.
class Transformation::GenerateVideo < Transformation::Generation
  def self.label = "Video"

  def self.video? = true

  def self.inputs = { first_frame: 1..1, last_frame: 0..1, reference: 0.., prompt: 0.. }

  def self.ports = [
    { name: "first_frame", label: "Start" },
    { name: "last_frame", label: "End" },
    { name: "reference", label: "Refs" },
    { name: "prompt", label: "Prompt" }
  ]

  def file
    first, last, refs = frame_blobs
    raise "This model only uses the start frame; disconnect End or pick another model." if last && !transformation.supports_last_frame?
    raise "This model doesn't take reference images; disconnect Refs or pick another model." if refs.any? && !transformation.supports_reference?

    args = ai_args
    with, provider_options = frame_args(first, last, refs, args[:provider], args[:provider_options].to_h)
    result = RubyLLM.animate(run.prompt_text, with:, **args, provider_options:)
    attachment(result.to_blob, "mp4", "video/mp4")
  end

  private

    # Named media roles from the run's sources (same greedy assignment as Validation).
    def frame_blobs
      assigned = run.assigned_inputs
      [
        assigned[:first_frame].first&.file&.blob,
        assigned[:last_frame].first&.file&.blob,
        assigned[:reference].map { it.file.blob }
      ]
    end

    # Frames go in `with:` (OpenRouter → frame_images; xAI image). Gemini first+last / refs go through
    # provider_options (deep_merge replaces arrays). Refs are never in `with:` (OpenRouter caps it at two frames).
    def frame_args(first, last, refs, provider, provider_options)
      provider_options = provider_options.merge(input_references: openrouter_refs(refs)) if refs.any? && provider == :openrouter

      case provider
      when :xai
        options = last ? provider_options.merge(last_frame: { url: llm_attachment(last).url_or_data_uri }) : provider_options
        [ [ first ], options ]
      when :gemini
        return [ [ first ], provider_options ] unless last || refs.any?

        instance = { prompt: run.prompt_text, image: veo_image(first) }
        instance[:lastFrame] = veo_image(last) if last
        instance[:referenceImages] = refs.map { { image: veo_image(it), referenceType: "ASSET" } } if refs.any?
        [ nil, provider_options.merge(instances: [ instance ]) ]
      else
        [ [ first, last ].compact, provider_options ]
      end
    end

    def openrouter_refs(blobs)
      blobs.map { |blob| { type: "image_url", image_url: { url: llm_attachment(blob).url_or_data_uri } } }
    end

    def llm_attachment(blob) = RubyLLM::Attachment.new(blob)

    def veo_image(blob)
      image = llm_attachment(blob)
      { bytesBase64Encoded: image.encoded, mimeType: image.mime_type }
    end
end
