# frozen_string_literal: true

# A transformation applied to items (media, prompts, reviews), e.g. a workflow step's batch. Its result, an item of the
# kind its type makes (a media, or a prompt for an LLM), lands in the given folder, created up front so a running or
# failed run already has a page; GenerateJob fills its file or text once the transformation's type makes it. As a step
# run it has its `workflow_run` and step `workflow_node`, and may share another run's result instead (`reused_from`).
# A run without a transformation records a version the owner dropped onto a media themselves; it never runs.
# `options` start from the transformation's (see GenerationOptions).
# `prompt_text` is set on start from the transformation as given, so a run with unsaved edits sends them; it also keeps
# the text as sent, as the transformation and prompts may change later.
class TransformationRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :transformation, optional: true
  belongs_to :workflow_run, optional: true
  belongs_to :workflow_node, optional: true
  # Not its `transformation_run`: a step run reusing it shares it.
  belongs_to :result, polymorphic: true, autosave: true
  has_many :inputs, -> { order(:position) }, class_name: "TransformationRunInput", inverse_of: :transformation_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validate :items_fit_transformation, on: :create, if: :transformation

  after_update_commit :broadcast_refresh, if: :saved_change_to_status?
  after_update_commit -> {
    workflow_run.advance!(workflow_node, result.user) if complete? && workflow_node
    workflow_run.broadcast_refresh_later
  }, if: -> { workflow_run && saved_change_to_status? }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  # Several runs' status as one: failed if any failed, else running if any is, else complete; nil for none.
  def self.status_of(runs) = %w[failed running complete].find { |s| runs.any? { it.status == s } }

  def video? = transformation&.video?

  def type = transformation&.type

  # Seconds from start to finish; nil while running.
  def duration = (updated_at - created_at unless running?)

  # The step run that made its result, when this one reuses it from another run (see WorkflowRun#reuse).
  def reused_from = result.transformation_run.then { it unless it == self }

  def inherited_options = transformation&.options

  # Every item it took, in order; also before save.
  def sources = inputs.map(&:item)
  def source_media = sources.grep(LibraryMedia)
  def prompts = sources.grep(Prompt)
  def review = sources.grep(Review).last

  # Its result when that's a media or a prompt.
  def generated_media = (result if result.is_a?(LibraryMedia))
  def generated_prompt = (result if result.is_a?(Prompt))

  # `user` owns the result, made in `folder` with `tags` (media) and the job of the first source media that has one.
  # Raises ActiveRecord::RecordInvalid when the items don't fit or an option isn't available.
  def start!(user, folder:, tags: [])
    self.result = if transformation.makes == :prompt
      Prompt.new(user:, folder:, name: "#{transformation.name} · #{Time.current.to_fs(:short)}", body: "")
    else
      LibraryMedia.new(user:, kind: transformation.video? || transformation.reel? || single_over_video? ? "video" : "photo", folder:, tags:,
        job: source_media.filter_map(&:job).first)
    end
    picked = transformation.picks?(:prompt) ? prompts : []
    self.prompt_text = [ transformation.body, *picked.map { "# #{it.folder.name}\n\n#{it.body}" } ].compact_blank.join("\n\n") if transformation.ai?
    save!
    GenerateJob.perform_later(self)
    self
  end

  # Makes the file or text the transformation's type's way (see Transformation::Type).
  def run!
    made = transformation.type.new(self)
    result.update!(transformation.makes == :prompt ? { body: made.body } : { file: made.file })
    update!(status: "complete", error: nil)
  rescue StandardError => e
    Rails.logger.error("[TransformationRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    def single_over_video? = transformation.single? && source_media.first&.video?

    # Every item fits one of the type's inputs, each input gets as many as it takes, and every item is the result's
    # owner's (a prompt may be shared).
    def items_fit_transformation
      items, inputs, owner = sources, transformation.inputs, result&.user_id
      fits = items.all? && items.uniq.size == items.size &&
        items.all? { it.user_id == owner || (it.is_a?(Prompt) && it.user_id.nil?) } &&
        items.all? { |item| inputs.keys.any? { transformation.fits?(it, item) } } &&
        inputs.all? { |kind, count| count.cover?(items.count { transformation.fits?(kind, it) }) }
      unless fits
        wanted = inputs.map { |kind, count| "#{count.begin}..#{count.end || "n"} #{kind.to_s.pluralize}" }.to_sentence
        errors.add(:base, "Give it #{wanted.presence || "nothing"}.")
      end
      errors.add(:base, "Add a prompt.") if transformation.ai? && transformation.body.blank?
    end
end
