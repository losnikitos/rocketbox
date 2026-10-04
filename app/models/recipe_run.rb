# frozen_string_literal: true

# A recipe applied to photobank photos, one per slot. The result is a Ready media, created up front so a running or
# failed run already has a page; GenerateJob attaches its file when the AI call finishes.
# `options` start from the recipe's (see GenerationOptions). `prompt` keeps the text as sent, as the recipe, shot and style may change later.
# ponytail: `source_media_ids` is a JSON array, so deleting a source photo leaves an id pointing at nothing
# (`source_media` skips it). Upgrade = a join table with a foreign key.
class RecipeRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :recipe, optional: true
  belongs_to :shot, optional: true
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :recipe_run

  validates :status, inclusion: { in: STATUSES }
  validate :media_fit_recipe, on: :create

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = false

  def styled? = true

  def inherited_options = recipe&.options

  def source_media
    LibraryMedia.where(user: generated_media.user, id: source_media_ids).with_attached_file.index_by(&:id).values_at(*source_media_ids).compact
  end

  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot doesn't fit or an option isn't available.
  def start!
    save!
    GenerateJob.perform_later(self)
    self
  end

  # One AI call composing the source photos.
  def run!
    opts = ai_options
    self.prompt = [ recipe.body, shot&.body, style&.body ].compact_blank.join("\n\n")
    result = RubyLLM.paint(prompt, model: opts[:model], provider: opts[:provider],
      with: source_media.map { it.file.blob }, provider_options: opts.except(:provider, :model))
    generated_media.update!(file: { io: StringIO.new(result.to_blob), filename: "recipe.jpg", content_type: "image/jpeg" })
    update!(status: "complete", error: nil, cost: result.cost.total)
  rescue StandardError => e
    Rails.logger.error("[RecipeRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    def media_fit_recipe
      return errors.add(:recipe, "is missing") unless recipe

      media = source_media
      fits = source_media_ids.size == recipe.media_type_ids.size && media.size == source_media_ids.size && source_media_ids.uniq.size == media.size &&
        media.zip(recipe.media_type_ids).all? { |item, type_id| item.photobank? && item.media_type_id == type_id && item.story_image? }
      errors.add(:base, "Pick a different photobank photo for every slot.") unless fits
      errors.add(:base, "Pick a shot from the recipe's shot group.") unless shot&.group == recipe.shot_group
    end
end
