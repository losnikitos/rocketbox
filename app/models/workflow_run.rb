# frozen_string_literal: true

# One go of a workflow: each step it runs is a TransformationRun (its `steps`), started once every node feeding it gives
# media. Played from a start folder, whose newest media feeds the steps downstream; a step starts the steps it feeds when
# it completes. A step that can't start leaves its reason in `error`. For now each workflow has one, its draft, replayed
# from scratch.
class WorkflowRun < ApplicationRecord
  belongs_to :workflow
  has_many :steps, -> { order(:id) }, class_name: "TransformationRun", inverse_of: :workflow_run

  # `node` is a start folder; `user` owns what the steps make. Drops what the last play made first.
  def start!(node, user)
    steps.includes(:generated_media).to_a.each { it.generated_media.destroy! }
    update!(error: nil)
    advance!(node, user)
  end

  # Starts the steps `node` feeds, directly or through a folder, that haven't run yet and whose inputs all give media.
  def advance!(node, user)
    with_lock do
      next_steps(node).each do |step|
        next if steps.exists?(workflow_node: step)
        media = edges.select { it.to_id == step.id }.map { give(it.from, user) }
        start_step(step, media, user) if media.all?
      end
    end
  end

  private

    def edges = @edges ||= workflow.edges.includes(:from, :to).to_a

    def next_steps(node)
      outs = edges.select { it.from_id == node.id }.map(&:to)
      (outs.select(&:step?) + outs.reject(&:step?).flat_map { |folder| edges.select { it.from_id == folder.id }.map(&:to) }).uniq
    end

    # A folder gives its newest media (with its tag), a media itself, a step what it made in this run once complete.
    def give(node, user)
      if node.step? then steps.find_by(workflow_node: node, status: "complete")&.generated_media
      elsif node.library_media then node.library_media
      else
        media = user.library_media.where(folder: node.folder)
        media = media.where(id: node.tag.library_media) if node.tag
        media.order(created_at: :desc).first
      end
    end

    # The result lands in the step's first output folder (with its tag), else Ready. A shot is picked at random.
    def start_step(step, media, user)
      transformation = step.transformation
      output = edges.find { it.from_id == step.id && !it.to.step? }&.to
      transformation.run!(media:, user:, folder: output&.folder || Folder.ready, tags: [ output&.tag ].compact,
        shot: (Shot.where(group: transformation.shot_group).sample if transformation.shot_group),
        review: (user.reviews.postable.last if transformation.takes_review?), workflow_run: self, workflow_node: step)
    rescue ActiveRecord::RecordInvalid => e
      update!(error: "#{step.label}: #{e.record.errors.full_messages.to_sentence}")
    end
end
