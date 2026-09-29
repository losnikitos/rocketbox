# frozen_string_literal: true

class Workflow
  # Incoming media become the post's slides, in `from:` order.
  class Output
    LABEL = "Output"
    ICON = "paper-airplane"

    def self.call(inputs:, params:, run:)
      post = run.smm_post
      media = inputs.map { it.video? ? it : MediaCanvas.fit(it, params["format"]) }
      SmmPost.transaction do
        post.smm_slides.destroy_all
        media.each_with_index { |item, index| post.smm_slides.create!(position: index, media: item) }
        post.update!(format: params["format"])
      end
      post.smm_slides.map { it.media.blob }
    end
  end
end
