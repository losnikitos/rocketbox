# frozen_string_literal: true

class Workflow
  # One of the post's selected library images (by slot), or all of them.
  class Input
    LABEL = "Input image"
    ICON = "photo"
    SCHEME = %i[image].freeze

    def self.call(inputs:, params:, run:)
      files = run.smm_post.smm_post_media_items.includes(library_media: { file_attachment: :blob })
        .filter_map { it.library_media.file.blob if it.library_media.file.attached? }
      return files if params["slot"].to_s == "all"

      [ files[params["slot"].to_i - 1] || raise(Error, "Image #{params["slot"]} is missing.") ]
    end
  end
end
