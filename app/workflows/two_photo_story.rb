# frozen_string_literal: true

class TwoPhotoStory < Workflow
  step :photo_1, Input, slot: 1
  step :photo_2, Input, slot: 2
  step :film_1, AiImage, from: :photo_1
  step :film_2, AiImage, from: :photo_2
  step :text_1, TextOverlay, from: :film_1, position: "top_center", size: "L", style: "shade"
  step :text_2, TextOverlay, from: :film_2, position: "middle_center", size: "L", style: "none"
  step :story, Output, from: %i[text_1 text_2], format: "story"
end
