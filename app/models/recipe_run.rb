# frozen_string_literal: true

# A recipe applied to library media, one per recipe input. The result lands in the recipe's output folder, created
# up front so a running or failed run already has a page; GenerateJob attaches its file once the recipe's type makes it.
# A run without a recipe records a version the owner dropped onto a media themselves; it never runs.
# `options` start from the recipe's (see GenerationOptions).
# `prompt` is set on start from the recipe as given, so a run with unsaved edits sends them; it also keeps the text
# as sent, as the recipe, shot and style may change later.
class RecipeRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :recipe, optional: true
  belongs_to :shot, optional: true
  belongs_to :style, optional: true
  belongs_to :review, optional: true
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :recipe_run
  has_many :inputs, -> { order(:position) }, class_name: "RecipeRunInput", inverse_of: :recipe_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validate :media_fit_recipe, on: :create, if: :recipe

  # The user's last recipe runs, for the Generations panel.
  scope :recent_for, ->(user) {
    where.not(recipe_id: nil).joins(:generated_media).where(library_media: { user_id: user.id })
      .includes(:recipe, generated_media: { file_attachment: :blob }).order(created_at: :desc).limit(5)
  }

  after_update_commit -> {
    broadcast_update_to [ generated_media.user, :generations ], target: "generations", partial: "layouts/app/generations", locals: { user: generated_media.user }
    broadcast_replace_to [ generated_media.user, :generations ], target: ActionView::RecordIdentifier.dom_id(generated_media, :made),
      partial: "accounts/recipes/made", locals: { media: generated_media }
  }, if: :saved_change_to_status?
  after_update_commit :broadcast_refresh, if: :saved_change_to_status?

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = recipe&.video?

  def inherited_options = recipe&.options

  # In slot order; also before save.
  def source_media = inputs.map(&:library_media)

  # `user` owns the result. Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot doesn't fit
  # or an option isn't available.
  def start!(user)
    build_generated_media(user:, kind: recipe.video? || recipe.reel? || layer_over_video? ? "video" : "photo", folder: recipe.output_folder)
    self.prompt = [ recipe.body, shot&.body, style&.body ].compact_blank.join("\n\n") if recipe.ai?
    save!
    GenerateJob.perform_later(self)
    self
  end

  # Makes the file the recipe's type's way (see RecipeType).
  def run!
    generated_media.update!(file: recipe.type.new(self).file)
    update!(status: "complete", error: nil)
  rescue StandardError => e
    Rails.logger.error("[RecipeRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    def layer_over_video? = recipe.overlay? && source_media.first&.video?

    def media_fit_recipe
      media = source_media
      fits = media.size == recipe.inputs.size && media.all? && media.all? { it.user_id == generated_media&.user_id } &&
        media.zip(recipe.inputs).all? { |item, slot| item.folder_id == slot["folder_id"] && recipe.takes?(item) }
      errors.add(:base, "Pick a matching photo for every input.") unless fits
      errors.add(:base, "Pick a shot from the recipe's shot group.") unless shot&.group == recipe.shot_group
      errors.add(:base, "Pick a review.") unless review.present? == recipe.takes_review? && (review.nil? || review.user_id == generated_media&.user_id)
    end
end
