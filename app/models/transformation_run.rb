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

  STATUSES = %w[running waiting complete failed rejected].freeze

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
    workflow_run.notify_settled! unless workflow_run.running?
  }, if: -> { workflow_run && saved_change_to_status? }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  # Several runs' status as one: failed if any failed, else rejected, waiting, running, else complete; nil for none.
  def self.status_of(runs) = %w[failed rejected waiting running complete].find { |s| runs.any? { it.status == s } }

  def video? = transformation&.video?

  def type = transformation&.type

  # Seconds from start to finish; nil while running or waiting.
  def duration = (updated_at - created_at unless running? || waiting?)

  # The step run that made its result, when this one reuses it from another run (see WorkflowRun#reuse).
  def reused_from = result.transformation_run.then { it unless it == self }

  def inherited_options = transformation&.options

  # Every item it took, in order; also before save.
  def sources = inputs.map(&:item)
  def source_media = sources.grep(LibraryMedia)
  def prompts = sources.grep(Prompt)
  def review = sources.grep(Review).last

  # Sources slotted into the type's named inputs: by `TransformationRunInput#input` when set, else greedily in
  # input order (ad-hoc runs without port names).
  def assigned_inputs
    if inputs.any? { it.input.present? }
      transformation.inputs.keys.index_with { [] }.tap do |out|
        inputs.each { |row| out[row.input.to_sym] << row.item if out.key?(row.input.to_sym) }
      end
    else
      remaining = sources.dup
      transformation.inputs.to_h do |name, count|
        matching = remaining.select { transformation.fits?(name, it) }
        take = matching.first([ count.end, matching.size ].compact.min)
        remaining -= take
        [ name, take ]
      end
    end
  end

  # Its result when that's a media or a prompt.
  def generated_media = (result if result.is_a?(LibraryMedia))
  def generated_prompt = (result if result.is_a?(Prompt))

  # The newest step run still waiting on this user, if any. That's the cursor for their next WhatsApp message.
  def self.waiting_for(user)
    where(status: "waiting", result_type: "LibraryMedia", result_id: user.library_media.select(:id)).order(id: :desc).first
  end

  # A waiting Collect whose start folder holds `media`, so the photo joins that run instead of opening another.
  def self.open_collect_for(media)
    user = media.user or return
    where(status: "waiting", result_type: "LibraryMedia", result_id: user.library_media.select(:id))
      .joins(:transformation).where(transformations: { kind: "collect" }).order(id: :desc)
      .detect { it.collects?(media) }
  end

  # `user` owns the result, made in `folder` with `tags` (media) and the job of the first source media that has one.
  # A relocating type (Sort) reuses the source media as the result and moves it later in `run!`.
  # A forwarding type (Collect, Publish) also reuses the first source, and passes every input on once complete.
  # Raises ActiveRecord::RecordInvalid when the items don't fit or an option isn't available.
  def start!(user, folder:, tags: [])
    type = transformation.type
    self.result = if type.relocates? || type.forwards?
      source_media.first.tap { |media| media.tags = media.tags.to_a | Array(tags) if tags.any? }
    elsif transformation.makes == :prompt
      Prompt.new(user:, folder:, name: "#{transformation.name} · #{Time.current.to_fs(:short)}", body: "")
    else
      LibraryMedia.new(user:, kind: transformation.video? || transformation.reel? || single_over_video? ? "video" : "photo", folder:, tags:,
        job: source_media.filter_map(&:job).first)
    end
    picked = transformation.picks?(:prompt) ? prompts : []
    self.prompt_text = [ transformation.body, *picked.map { "# #{it.folder.name}\n\n#{it.body}" } ].compact_blank.join("\n\n") if transformation.ai?
    if type.waits? && type.hold?(self)
      self.status = "waiting"
      save!
      RequestApproval.call(self) if transformation.kind == "approval"
    elsif type.forwards? && !type.waits?
      save!
      announce!
      GenerateJob.perform_later(self)
    elsif type.forwards?
      self.status = "complete"
      save!
    else
      save!
      announce!
      GenerateJob.perform_later(self)
    end
    self
  end

  # Makes the file or text the transformation's type's way (see Transformation::Type).
  # A relocating type moves the source media into the folder its type picks.
  # A forwarding type runs its side effect (Publish) and keeps the source.
  def run!
    made = transformation.type.new(self)
    if transformation.type.relocates?
      result.update!(folder: made.folder)
    elsif transformation.type.forwards?
      made.finish if made.respond_to?(:finish)
    else
      result.update!(transformation.makes == :prompt ? { body: made.body } : { file: made.file })
    end
    update!(status: "complete", error: nil)
  rescue StandardError => e
    Rails.logger.error("[TransformationRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  # Pass-through the source media and continue the workflow. Only from a waiting Approval.
  def approve!
    raise "Not waiting for approval" unless waiting? && transformation&.kind == "approval"
    run!
  end

  # Stop this branch; downstream steps stay quiet. Only from a waiting Approval.
  def reject!
    raise "Not waiting for approval" unless waiting? && transformation&.kind == "approval"
    update!(status: "rejected", error: nil)
  end

  # Send this step's WhatsApp line again. Approval resends its buttons; anything else resends its start text.
  def remind!
    if transformation&.kind == "approval"
      RequestApproval.call(self)
    else
      announce!
    end
  end

  # Text to the result's owner. A button and url send a link button; otherwise plain text.
  # Blank text, an AI prompt, or no phone sends nothing. A WhatsApp failure is logged, not raised.
  def announce!(text = transformation&.body, button: nil, url: nil)
    to = result&.user&.whatsapp_phone.presence or return
    return if text.blank? || transformation&.ai?

    if button.present? && url.present?
      WhatsappCloud.send_cta_url(phone_number_id: WhatsappCloud.phone_number_id, to:, body: text,
        display_text: button.to_s.truncate(20, omission: ""), url:)
    else
      WhatsappCloud.send_text(phone_number_id: WhatsappCloud.phone_number_id, to:, body: text)
    end
  rescue StandardError => e
    Rails.logger.warn("[TransformationRun] whatsapp run=#{id} #{e.class}: #{e.message}")
  end

  # Whether `media` sits in a folder that feeds this step.
  def collects?(media) = collect_start(media).present?

  # Append `media` to this waiting Collect and, once it has enough photos, complete it so the run continues.
  # True when the photo is now part of this run. No `return` inside the lock: that would roll the transaction back.
  def accept_media!(media)
    joined = false
    with_lock do
      if waiting? && transformation&.kind == "collect"
        if inputs.exists?(item_type: media.class.name, item_id: media.id)
          joined = true
        elsif (start = collect_start(media))
          key = start.id.to_s
          ids = Array(workflow_run.picks[key]).map(&:to_i)
          workflow_run.update!(picks: workflow_run.picks.merge(key => ids + [ media.id ]))
          inputs.create!(item: media, input: transformation.inputs.keys.first.to_s, position: inputs.maximum(:position).to_i + 1)
          update!(status: "complete") if inputs.count >= Transformation::Collect::COUNT
          joined = true
        end
      end
    end
    joined
  end

  private

    def single_over_video? = transformation.single? && source_media.first&.video?

    def collect_start(media)
      return unless workflow_node_id && media

      WorkflowEdge.where(to_id: workflow_node_id).includes(:from).find { it.from&.takes?(media) }&.from
    end

    # Every item fits one of the type's inputs, each input gets as many as it takes (items assigned greedily in input
    # order so Start / End / Refs don't double-count the same photos), and every item is the result's owner's (a prompt
    # may be shared).
    def items_fit_transformation
      items, inputs, owner = sources, transformation.inputs, result&.user_id
      assigned = assigned_inputs
      leftover = items.size - assigned.values.sum(&:size)
      fits = items.all? && items.uniq.size == items.size && leftover.zero? &&
        items.all? { it.user_id == owner || (it.is_a?(Prompt) && it.user_id.nil?) } &&
        inputs.all? { |name, count| count.cover?(assigned[name].size) }
      unless fits
        wanted = inputs.map { |name, count| "#{count.begin}..#{count.end || "n"} #{name.to_s.pluralize}" }.to_sentence
        errors.add(:base, "Give it #{wanted.presence || "nothing"}.")
      end
      errors.add(:base, "Add a prompt.") if transformation.ai? && transformation.body.blank?
    end
end
