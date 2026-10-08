# frozen_string_literal: true

# A transformation applied to library media, e.g. each recipe input's count from its folder. The result lands in the
# given folder, created up front so a running or failed run already has a page; GenerateJob attaches its file once the
# transformation's type makes it. `recipe` is the one it ran for, if any, or `workflow_run` and its step `workflow_node`.
# A run without a transformation records a version the owner dropped onto a media themselves; it never runs.
# `options` start from the transformation's (see GenerationOptions).
# `prompt` is set on start from the transformation as given, so a run with unsaved edits sends them; it also keeps the
# text as sent, as the transformation, shot and style may change later.
class TransformationRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :transformation, optional: true
  belongs_to :recipe, optional: true
  belongs_to :shot, optional: true
  belongs_to :style, optional: true
  belongs_to :review, optional: true
  belongs_to :workflow_run, optional: true
  belongs_to :workflow_node, optional: true
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :transformation_run
  has_many :inputs, -> { order(:position) }, class_name: "TransformationRunInput", inverse_of: :transformation_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validate :media_fit_transformation, on: :create, if: :transformation

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
  after_update_commit -> {
    workflow_run.advance!(workflow_node, generated_media.user) if complete? && workflow_node
    workflow_run.broadcast_refresh_later
  }, if: -> { workflow_run && saved_change_to_status? }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = transformation&.video?

  def inherited_options = transformation&.options

  # In the order picked; also before save.
  def source_media = inputs.map(&:library_media)

  # `user` owns the result, made in `folder` with `tags`. Raises ActiveRecord::RecordInvalid when the media don't fit,
  # the shot doesn't fit or an option isn't available.
  def start!(user, folder:, tags: [])
    build_generated_media(user:, kind: transformation.video? || transformation.reel? || single_over_video? ? "video" : "photo", folder:, tags:)
    self.prompt = [ transformation.body, shot&.body, style&.body ].compact_blank.join("\n\n") if transformation.ai?
    save!
    GenerateJob.perform_later(self)
    self
  end

  # Makes the file the transformation's type's way (see Transformation::Type).
  def run!
    generated_media.update!(file: transformation.type.new(self).file)
    update!(status: "complete", error: nil)
  rescue StandardError => e
    Rails.logger.error("[TransformationRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    def single_over_video? = transformation.single? && source_media.first&.video?

    def media_fit_transformation
      media = source_media
      fits = media.any? && media.all? && media.uniq.size == media.size &&
        media.all? { it.user_id == generated_media&.user_id && transformation.takes?(it) } && (recipe.nil? || recipe.fills_inputs?(media))
      errors.add(:base, "Pick the right number of media for every input.") unless fits
      errors.add(:base, "Pick a shot from the shot group.") unless shot&.group == transformation.shot_group
      errors.add(:base, "Pick a review.") unless review.present? == transformation.takes_review? && (review.nil? || review.user_id == generated_media&.user_id)
    end
end
