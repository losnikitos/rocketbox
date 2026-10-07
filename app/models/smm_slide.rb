# frozen_string_literal: true

class SmmSlide < ApplicationRecord
  belongs_to :smm_post
  has_one_attached :media do |media|
    media.variant :thumb, resize_to_limit: [ 720, 720 ], preprocessed: :video?
  end

  def video?
    media.attached? && media.content_type.to_s.start_with?("video/")
  end
end
