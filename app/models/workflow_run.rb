# frozen_string_literal: true

# One go of a workflow: each step it runs is a step run (its `step_runs`, a TransformationRun), started once every node
# feeding the step outputs media. Played from a start folder or media, whose (newest) media feeds the steps downstream; a step run
# starts the steps its step feeds when it completes. A step run stands across plays while it stands (see
# `stands?`), so a replay reruns only the steps whose inputs or transformation changed and the steps after them;
# `rerun!` forces a step anyway, e.g. once its type's code changed, or starts one whose inputs completed. A step that can't start leaves its reason in
# `error`. For now each workflow has one, its draft.
class WorkflowRun < ApplicationRecord
  belongs_to :workflow
  has_many :step_runs, -> { order(:id) }, class_name: "TransformationRun", inverse_of: :workflow_run

  # `node` is a start folder or media; `user` owns what the step runs make.
  def start!(node, user)
    update!(error: nil)
    advance!(node, user)
  end

  # Drops `step`'s step run, if any, and the ones after it, and starts it from what its inputs give now.
  def rerun!(step, user)
    update!(error: nil)
    with_lock { step_runs.find_by(workflow_node: step)&.then { drop(it) } }
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

    # Stale step runs go first, with the ones after them, so no step starts from a stale result. Then a step whose step
    # run stands moves its result to the step's output folder, should that have changed, and on to the steps after it
    # once complete; a step without one starts once its inputs all give media.
    def run_steps(steps, user)
      with_lock do
        steps.each { |step| step_runs.find_by(workflow_node: step)&.then { drop(it) unless stands?(it, inputs_of(step, user)) } }
        steps.each do |step|
          if (run = step_runs.find_by(workflow_node: step))
            output = output_of_step(step)
            run.generated_media&.update!(folder: output&.folder || Folder.ready, tags: run.generated_media.tags | [ output&.tag ].compact)
            advance!(step, user) if run.complete?
          elsif (media = inputs_of(step, user)).all? then start_step(step, media, user)
          end
        end
      end
    end

    # A step run stands while it hasn't failed, took what the step's inputs give now, and its transformation wasn't
    # saved since it started.
    # ponytail: a style's or shot's text or a newly postable review don't count; rerun! covers them.
    def stands?(run, media) = !run.failed? && run.source_media == media && run.created_at >= run.transformation.updated_at

    # Its result goes, and before it the step runs that took it, as their inputs go with it.
    def drop(run)
      step_runs.joins(:inputs).where(transformation_run_inputs: { library_media_id: run.generated_media_id }).each { drop(it) }
      run.generated_media&.destroy!
    end

    def inputs_of(step, user) = edges.select { it.to_id == step.id }.map { output_of(it.from, user) }

    # A node's output in this run: a folder its newest media (with its tag), a media itself, a step what its step run
    # made once complete.
    def output_of(node, user)
      if node.step? then step_runs.find_by(workflow_node: node, status: "complete")&.generated_media
      elsif node.library_media then node.library_media
      else
        media = user.library_media.where(folder: node.folder)
        media = media.where(id: node.tag.library_media) if node.tag
        media.order(created_at: :desc).first
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
