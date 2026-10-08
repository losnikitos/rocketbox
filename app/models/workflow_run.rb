# frozen_string_literal: true

# One go of a workflow: each step it runs is a step run (its `step_runs`, a TransformationRun), started once every node
# feeding the step outputs media. Played from a start folder or media, whose newest media feed the steps downstream; a step run
# starts the steps its step feeds when it completes. Every node gives a list: a reel step takes all of it in one step run, its
# slots in order; any other step takes one item per step run, its shorter inputs repeating their last media (ComfyUI's
# lists), and gives what they all made once they're all complete. A step run stands across plays while it stands (see
# `stands?`), so a replay reruns only the step runs whose inputs or transformation changed and the ones after them;
# `rerun!` forces a step anyway, e.g. once its type's code changed, or starts one whose inputs completed. A step that can't start leaves its reason in
# `error`. A workflow has as many as were added, each named Run N.
class WorkflowRun < ApplicationRecord
  belongs_to :workflow
  has_many :step_runs, -> { order(:id) }, class_name: "TransformationRun", inverse_of: :workflow_run

  before_create { self.name = "Run #{workflow.runs.count + 1}" }

  def running? = step_runs.any?(&:running?)

  # `node` is a start folder or media; `user` owns what the step runs make.
  def start!(node, user)
    update!(error: nil)
    advance!(node, user)
  end

  # Drops `step`'s step runs and the ones after them, and starts it from what its inputs give now.
  def rerun!(step, user)
    update!(error: nil)
    with_lock { runs_of(step).each { drop(it) } }
    run_steps([ step ], user)
  end

  # Runs the steps `node` feeds, directly or through a folder.
  def advance!(node, user) = run_steps(next_steps(node), user)

  private

    def edges = @edges ||= workflow.edges.includes(:from, :to).to_a

    def next_steps(node)
      outs = edges.select { it.from_id == node.id }.map(&:to)
      (outs.select(&:step?) + outs.reject(&:step?).flat_map { |folder| edges.select { it.from_id == folder.id }.map(&:to) }).uniq
    end

    def runs_of(step) = step_runs.where(workflow_node: step).includes(inputs: :library_media).to_a

    # Stale step runs go first, with the ones after them, so no step starts from a stale result. Then each of a step's
    # batches either has a step run that stands, whose result moves to the step's output folder should that have
    # changed, or starts one; once they're all complete, the steps after it go on.
    def run_steps(steps, user)
      with_lock do
        steps.each do |step|
          batches = batches_of(step, user)
          runs_of(step).each { |run| drop(run) unless batches.any? { stands?(run, it) } }
        end
        steps.each do |step|
          output, runs = output_of_step(step), runs_of(step)
          batches_of(step, user).each do |batch|
            if (run = runs.find { it.source_media == batch })
              run.generated_media&.update!(folder: output&.folder || Folder.ready, tags: run.generated_media.tags | [ output&.tag ].compact)
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

    # Its result goes, and before it the step runs that took it, as their inputs go with it.
    def drop(run)
      step_runs.joins(:inputs).where(transformation_run_inputs: { library_media_id: run.generated_media_id }).each { drop(it) }
      run.generated_media&.destroy!
    end

    # Each input's media, slot by slot in the type's order, then in the order they were connected.
    def inputs_of(step, user)
      slots = step.transformation.slots
      edges.select { it.to_id == step.id }.sort_by { [ slots&.index(it.slot).to_i, it.id ] }.map { output_of(it.from, user) }
    end

    # The media of each step run the step makes from what its inputs give now, none while an input gives nothing.
    def batches_of(step, user)
      inputs = inputs_of(step, user)
      return [] if inputs.empty? || inputs.any?(&:empty?)
      return [ inputs.flatten ] if step.transformation.reel?
      Array.new(inputs.map(&:size).max) { |i| inputs.map { it[i] || it.last } }
    end

    # A node's output in this run: a folder its newest media (with its tag), a media itself, a step what its step runs
    # made, in its batches' order, once they're all complete.
    def output_of(node, user)
      if node.step?
        runs = runs_of(node).select(&:complete?)
        made = batches_of(node, user).map { |batch| runs.find { it.source_media == batch }&.generated_media }
        made.all? ? made : []
      elsif node.library_media then [ node.library_media ]
      else
        media = user.library_media.where(folder: node.folder)
        media = media.where(id: node.tag.library_media) if node.tag
        media.order(created_at: :desc).limit(node.newest).to_a
      end
    end

    def output_of_step(step) = edges.find { it.from_id == step.id && !it.to.step? }&.to

    # The result lands in the step's first output folder (with its tag), else Ready. A shot is picked at random.
    def start_step(step, media, user)
      transformation = step.transformation
      output = output_of_step(step)
      transformation.run!(media:, user:, folder: output&.folder || Folder.ready, tags: [ output&.tag ].compact,
        shot: (Shot.where(group: transformation.shot_group).sample if transformation.shot_group),
        review: (user.reviews.postable.last if transformation.takes_review?), workflow_run: self, workflow_node: step)
    rescue ActiveRecord::RecordInvalid => e
      update!(error: "#{step.label}: #{e.record.errors.full_messages.to_sentence}")
    end
end
