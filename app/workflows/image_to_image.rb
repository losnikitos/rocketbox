# frozen_string_literal: true

class ImageToImage < Workflow
  step :photo, Input, slot: 1
  step :image, AiImage, from: :photo
  step :post, Output, from: :image, format: "post"
end
