# frozen_string_literal: true

# One go of a workflow: each step it runs is a step run (its `step_runs`, a TransformationRun), started once every node
# feeding the step outputs media. Played from a start folder or media, whose pinned or newest media feed the steps
# downstream; a step run starts the steps its step feeds when it completes; a run of one media (autorun, a media page's
# Run in workflow) holds it in `picks`, in place of the folder's. Every node gives a list: a step taking many inputs
# (`Transformation::Type.inputs`, e.g. a video or a reel) takes all of them in one step run, its slots in order; a
# single-input step takes one media per step run, and gives what they all made once they're all complete. A step run stands across plays while it stands (see
# `stands?`), so a replay reruns only the step runs whose inputs or transformation changed and the ones after them, and
# a step run that stands in another run is reused, sharing its result (`reuse`), so a new run makes only what's new;
# `rerun!` forces a step afresh anyway, e.g. once its type's code changed, or starts one whose inputs completed. A step that can't start leaves its reason in
# `error`. A workflow has as many as were added, each named Run N. A run is a draft until it's first played (from a start
# node or a step); then it's started.
class WorkflowRun < ApplicationRecord
  STATUSES = %w[draft started].freeze

  belongs_to :workflow
  has_many :step_runs, -> { order(:id) }, class_name: "TransformationRun", inverse_of: :workflow_run

  validates :status, inclusion: { in: STATUSES }
  normalizes :error, with: -> { it.presence }

  before_create { self.name = "Run #{workflow.runs.count + 1}" }

  def running? = step_runs.any?(&:running?)
  def draft? = status == "draft"

  # Draft until first played; then failed, running or complete, as its step runs (nil while none started).
  def state = draft? ? "draft" : error ? "failed" : TransformationRun.status_of(step_runs)

  # What it was played with and what it ended with: media its step runs took that none made, and made that none took.
  def inputs = took - made
  def outputs = made - took

  # `nodes` are start folders or media; `user` owns what the step runs make.
  def start!(nodes, user)
    update!(error: nil, status: "started", updated_at: Time.current)
    run_steps(Array(nodes).flat_map { next_steps(it) }.uniq, user)
  end

  # Drops `step`'s step runs and the ones after them, and starts it afresh from what its inputs give now, the steps
  # feeding it that haven't run here reusing their step runs from other runs first.
  def rerun!(step, user)
    update!(error: nil, status: "started", updated_at: Time.current)
    with_lock do
      reuse_inputs(step, user)
      runs_of(step).each { drop(it) }
    end
    run_steps([ step ], user, fresh: step)
  end

  # Runs the steps `node` feeds, directly or through a folder.
  def advance!(node, user) = run_steps(next_steps(node), user)

  # What a folder node gives in this run: the media picked for it in `picks` (node id => media ids), else its pinned
  # media, else its newest N; only the user's media still in the folder (with all its tags, of its type), newest first.
  def picked(node, user)
    media = user.library_media.where(folder: node.folder).tagged_all(node.tags.ids).of_type(node.media_type)
    media = (ids = picks[node.id.to_s] || node.pinned_media_ids.presence) ? media.where(id: ids) : media.limit(node.take)
    media.order(created_at: :desc).to_a
  end

  # What `node` gives in this run (see output_of), a step's batches not run here counting what another run's step run
  # would give through `reuse`: what the canvas draws as ready to go along its arrows.
  def gives(node, user) = output_of(node, user, cached: true)

  private

    def took = step_runs.flat_map(&:source_media).uniq
    def made = step_runs.filter_map(&:generated_media)

    def edges = @edges ||= workflow.edges.includes(:from, :to).to_a

    def next_steps(node)
      outs = edges.select { it.from_id == node.id }.map(&:to)
      (outs.select(&:step?) + outs.reject(&:step?).flat_map { |folder| edges.select { it.from_id == folder.id }.map(&:to) }).uniq
    end

    def runs_of(step) = step_runs.where(workflow_node: step).includes(inputs: :library_media).to_a

    # Stale step runs go first, with the ones after them, so no step starts from a stale result. Then each of a step's
    # batches either has a step run that stands, reuses one from another run (except the `fresh` step's), whose result
    # moves to the step's output folder should that have changed, or starts one; once they're all complete, the steps
    # after it go on.
    def run_steps(steps, user, fresh: nil)
      with_lock do
        steps.each do |step|
          batches = batches_of(step, user)
          runs_of(step).each { |run| drop(run) unless batches.any? { stands?(run, it) } }
        end
        steps.each do |step|
          output, runs = output_of_step(step), runs_of(step)
          batches_of(step, user).each do |batch|
            if (run = runs.find { it.source_media == batch } || (reuse(step, batch) unless step == fresh))
              run.generated_media&.update!(folder: output&.folder || Folder.ready, tags: run.generated_media.tags | step.tags)
            else start_step(step, batch, user)
            end
          end
          advance!(step, user) if output_of(step, user).any?
        end
      end
    end

    # A step run stands while it hasn't failed, took `media`, and its transformation wasn't saved since it started.
    # ponytail: a style's or shot's text or a newly postable review don't count; rerun! covers them.
    def stands?(run, media) = !run.failed? && run.source_media == media && run.created_at >= run.transformation.updated_at

    # A complete step run of the step's transformation, from any run, that took `media` and stands, copied into this one
    # with its result shared, so the steps after it reuse theirs too; nil when there's none.
    def reuse(step, media)
      prior = prior(step, media) or return
      copy = prior.dup
      copy.assign_attributes(workflow_run: self, workflow_node: step, cost: nil, inputs: prior.inputs.map(&:dup))
      copy if copy.save
    end

    # Copies in the step runs each step feeding `step` would reuse (see gives), the steps feeding those first, so `step`
    # can start here from cached results.
    def reuse_inputs(step, user)
      edges.select { it.to_id == step.id && it.from.step? }.map(&:from).each do |from|
        next if output_of(from, user).any?
        reuse_inputs(from, user)
        batches_of(from, user).each { |batch| runs_of(from).any? { it.source_media == batch } || reuse(from, batch) }
      end
    end

    # A complete step run of the step's transformation, from any run, that took `media` and stands.
    def prior(step, media)
      transformation = step.transformation
      transformation.runs.where(status: "complete", created_at: transformation.updated_at..)
        .includes(inputs: :library_media).find { it.source_media == media }
    end

    # Its result goes, unless another step run shares it, and before it the step runs here that took it, as their
    # inputs go with it.
    def drop(run)
      step_runs.joins(:inputs).where(transformation_run_inputs: { library_media_id: run.generated_media_id }).each { drop(it) }
      run.generated_media.transformation_runs.many? ? run.destroy! : run.generated_media.destroy!
    end

    # Each input's media, slot by slot in the type's order, then in the order they were connected.
    def inputs_of(step, user, cached: false)
      slots = step.transformation.slots
      edges.select { it.to_id == step.id }.sort_by { [ slots&.index(it.slot).to_i, it.id ] }.map { output_of(it.from, user, cached:) }
    end

    # The media of each step run the step makes from what its inputs give now, none while an input gives nothing: a
    # single-input step's one per media, any other's all of them in one.
    def batches_of(step, user, cached: false)
      inputs = inputs_of(step, user, cached:)
      return [] if inputs.empty? || inputs.any?(&:empty?)
      step.transformation.inputs == 1 ? inputs.flatten.map { [ it ] } : [ inputs.flatten ]
    end

    # A node's output in this run: a folder what's picked of it, a media itself, a step what its step runs made, in its
    # batches' order, once they're all complete. `cached` counts a batch's prior step run (see gives); running never
    # does, or a rerun! step's old result would start the steps after it.
    def output_of(node, user, cached: false)
      if node.step?
        runs = runs_of(node).select(&:complete?)
        made = batches_of(node, user, cached:).map do |batch|
          runs.find { it.source_media == batch }&.generated_media || (prior(node, batch)&.generated_media if cached)
        end
        made.all? ? made : []
      elsif node.library_media then [ node.library_media ]
      else picked(node, user)
      end
    end

    def output_of_step(step) = edges.find { it.from_id == step.id && !it.to.step? }&.to

    # The result, with the step's tags, lands in the step's first output folder, else Ready. A shot is picked at random.
    def start_step(step, media, user)
      transformation = step.transformation
      transformation.run!(media:, user:, folder: output_of_step(step)&.folder || Folder.ready, tags: step.tags,
        shot: (Shot.where(group: transformation.shot_group).sample if transformation.shot_group),
        review: (user.reviews.postable.last if transformation.takes_review?), workflow_run: self, workflow_node: step)
    rescue ActiveRecord::RecordInvalid => e
      update!(error: "#{step.label}: #{e.record.errors.full_messages.to_sentence}")
    end
end
