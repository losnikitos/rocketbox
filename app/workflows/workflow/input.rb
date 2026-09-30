# frozen_string_literal: true

class Workflow
  # One of the subject's input library images (by slot), or all of them.
  class Input
    LABEL = "Input image"
    ICON = "photo"
    SCHEME = %i[image].freeze

    def self.call(inputs:, params:, run:)
      files = run.subject.input_media.filter_map { it.file.blob if it.file.attached? }
      return files if params["slot"].to_s == "all"

      [ files[params["slot"].to_i - 1] || raise(Error, "Image #{params["slot"]} is missing.") ]
    end
  end
end
