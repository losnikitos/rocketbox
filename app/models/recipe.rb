# frozen_string_literal: true

# A template for a post: a prompt that composes one image from several photobank photos, one per slot.
# `media_type_ids` lists the slots in order and may repeat a type (two staff photos).
# `options` are the defaults for its posts (see GenerationOptions).
# ponytail: slots are a JSON array, so deleting a media type leaves a recipe slot pointing at nothing
# (the recipe then fails validation on edit). Upgrade = a recipe_slots join table with a foreign key.
class Recipe < ApplicationRecord
  include GenerationOptions

  # Posts outlive their recipe.
  has_many :smm_posts, dependent: :nullify

  enum :format, %w[post story reel].index_by(&:itself), validate: true

  before_validation { self.media_type_ids = Array(media_type_ids).compact_blank.map(&:to_i) }

  validates :name, :body, :media_type_ids, presence: true
  validate do
    errors.add(:media_type_ids, "include an unknown media type") unless MediaType.where(id: media_type_ids).count == media_type_ids.uniq.size
  end

  scope :ordered, -> { order(:name) }

  def video? = false

  def media_types = MediaType.where(id: media_type_ids).index_by(&:id).values_at(*media_type_ids)

  # `media` are library media in slot order; `options` override the recipe's. Raises ActiveRecord::RecordInvalid
  # when the media don't fit the slots or an option isn't available.
  def create_post!(user:, media:, options: {})
    post = smm_posts.new(user:, format:, status: "generating", options:)
    media.each_with_index { |item, position| post.smm_post_media_items.build(library_media: item, position:) }
    post.save!
    GenerateSmmPostJob.perform_later(post.id)
    post
  end
end
