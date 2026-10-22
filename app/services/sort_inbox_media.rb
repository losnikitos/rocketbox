# frozen_string_literal: true

# Picks an Inbox subfolder for a photo or video with a vision model; Misc when none fits.
# Used by the Sort workflow step (and tests). Pass `folders:` to limit the enum to connected outputs.
class SortInboxMedia
  PROMPT = <<~TEXT.strip
    You are sorting a photo a small business owner sent in, for their social media. Pick the one folder it belongs in.
    Use misc for anything no other folder fits. The folders, as slug: name:
  TEXT

  def self.classify(media, folders: Folder.inbox.children, prompt: PROMPT, model: nil, provider: nil) =
    new(media, folders:, prompt:, model:, provider:).classify

  def initialize(media, folders: Folder.inbox.children, prompt: PROMPT, model: nil, provider: nil)
    @media = media
    @folders = Array(folders)
    @prompt = prompt
    @model = model
    @provider = provider
  end

  # The chosen folder. Raises when the media has no image, folders are empty, or the model fails.
  def classify
    image = if @media.story_image? then @media.file
    elsif @media.video? then @media.file.preview(resize_to_limit: [ 720, 720 ]).processed.image
    end
    raise "Need a photo or video frame to sort" unless image
    raise "Connect at least one output folder" if @folders.empty?

    slug = RubyLLM.chat(model: @model, provider: (@provider.to_sym if @model))
      .with_schema(schema)
      .ask("#{@prompt}\n#{@folders.map { "- #{it.slug}: #{it.name}" }.join("\n")}", with: image)
      .parsed["folder"]
    @folders.find { it.slug == slug } or raise "Unknown folder #{slug}"
  end

  private

    def schema = {
      type: "object",
      properties: { folder: { type: "string", enum: @folders.map(&:slug) } },
      required: [ "folder" ],
      additionalProperties: false
    }
end
