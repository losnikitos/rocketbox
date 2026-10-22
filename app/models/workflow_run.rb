# frozen_string_literal: true

# One go of a workflow: each step it runs is a step run (its `step_runs`, a TransformationRun), started once every node
# feeding the step outputs items. Played from a start node (a folder or media), whose items feed the steps downstream:
# a folder its pinned or newest items: media, prompts or Reviews' 5-star reviews. A step run starts
# the steps its step feeds when it completes; a run of one media (autorun, a media page's Run in workflow) holds it in
# `picks`, in place of the folder's. A step taking nothing it isn't given (an LLM writing from its instruction alone)
# is a start node itself. Every node gives a list of items of one kind, each going into the step's input of that kind
# (`Transformation::Type.inputs`): a media input of 1 takes one item per step run, the step giving what they all made
# once they're all complete; a prompt or review input picks one per arrow into it per step run (a prompt at random,
# the newest review), except an LLM's; any other input takes all its items in each step run (e.g. a video, a reel). A step run
# stands across plays while it stands (see `stands?`), so a replay keeps its picks and reruns only the step runs whose
# inputs or transformation changed and the ones after them, and a step run that stands in another run is reused, sharing its result (`reuse`), so a new run makes only what's new;
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

  # Busy while a step is generating or waiting on approval (blocks settle notify and run delete).
  def running? = step_runs.any? { it.running? || it.waiting? }
  def draft? = status == "draft"

  # Draft until first played; then failed, rejected, waiting, running or complete, as its step runs (nil while none started).
  def state = draft? ? "draft" : error ? "failed" : TransformationRun.status_of(step_runs)

  # What it was played with and what it ended with: items its step runs took that none made, and made that none took.
  def inputs = took - made
  def outputs = made - took

  # `nodes` are start nodes; `user` owns what the step runs make.
  def start!(nodes, user)
    update!(error: nil, status: "started", updated_at: Time.current)
    run_steps(Array(nodes).flat_map { it.step? ? [ it ] : next_steps(it) }.uniq, user)
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

  # When every step run has finished, wake the owner's agent unless this workflow already texts them.
  def notify_settled!
    return if running? || draft? || tells_owner?

    user = step_runs.filter_map { it.result.try(:user) }.first
    WakeAgentJob.schedule(user) if user
  end

  # What a folder node gives in this run, as the user: its items picked in `picks` (node id => media ids, a media
  # folder's, in that order), else its pinned items in pin order, else its newest N, of its candidates.
  def picked(node, user)
    items = candidates(node, user)
    if (ids = picks[node.id.to_s] || node.pinned_ids.presence)
      found = items.where(id: ids).index_by(&:id)
      ids.filter_map { |id| found[id.to_i] }
    else
      items.limit(node.take).to_a
    end
  end

  # What a folder node can give from the folder (and its subfolders when `include_subfolders`), newest first. A media
  # folder: the user's media still in them (with all its tags, of its type). A prompt folder: their written prompts,
  # shared or the user's. Reviews: the user's 5-star reviews.
  def candidates(node, user)
    folder_id = node.folder_ids
    case node.folder.kind
    when "prompt" then Prompt.where(folder_id:).written.where(user_id: [ nil, user.id ]).order(id: :desc)
    when "review" then user.reviews.postable.where(folder_id:).order(id: :desc)
    else user.library_media.where(folder_id:).tagged_all(node.tags.ids).of_type(node.media_type).order(created_at: :desc)
    end
  end

  # What `node` gives in this run (see output_of), a step's batches not run here counting what another run's step run
  # would give through `reuse`: what the canvas draws as ready to go along its arrows.
  def gives(node, user) = output_of(node, user, cached: true)

  private

    # Approval, Publish and other non-AI steps send their own WhatsApp line. The agent would repeat it.
    def tells_owner?
      step_runs.includes(:transformation).any? { |step| (t = step.transformation) && !t.ai? && t.body.present? }
    end

    def took = step_runs.flat_map(&:sources).uniq
    def made = step_runs.filter_map(&:result)

    def edges = @edges ||= workflow.edges.includes(:from, :to).to_a

    def next_steps(node)
      outs = edges.select { it.from_id == node.id }.map(&:to)
      (outs.select(&:step?) + outs.reject(&:step?).flat_map { |folder| edges.select { it.from_id == folder.id }.map(&:to) }).uniq
    end

    def runs_of(step) = step_runs.where(workflow_node: step).includes(inputs: :item).to_a

    # Stale step runs go first, with the ones after them, so no step starts from a stale result. Then each of a step's
    # batches either has a step run that stands, reuses one from another run (except the `fresh` step's), whose result
    # moves to the step's output folder should that have changed, or starts one; once they're all complete, the steps
    # after it go on.
    def run_steps(steps, user, fresh: nil)
      with_lock do
        steps.each do |step|
          batches, sides = batches_of(step, user), sides_of(step, user)
          runs_of(step).each { |run| drop(run) unless batches.any? { stands?(run, it, sides) } }
        end
        steps.each do |step|
          runs, sides = runs_of(step), sides_of(step, user)
          batches = batches_of(step, user)
          if batches.empty?
            reason = unready_reason(step, user) and update!(error: "#{step.label}: #{reason}")
            next
          end
          batches.each do |batch|
            if (run = runs.find { matches?(it, batch, sides) } || (reuse(step, batch, sides) unless step == fresh))
              land(run.result, step)
            else start_step(step, batch, sides, user)
            end
          end
          advance!(step, user) if output_of(step, user).any?
        end
      end
    end

    # Why a step whose arrows give something still has no batches (e.g. a video into an image input); nil while an arrow
    # is empty, so a downstream step waiting on one before it stays quiet.
    def unready_reason(step, user)
      transformation = step.transformation
      given = given_to(step, user) or return
      short = transformation.inputs.select { |kind, count| given[kind].size < count.begin }
      return if short.empty?
      short.map { |name, count| "needs #{count.begin}+ #{name.to_s.humanize(capitalize: false).pluralize(count.begin)}, got #{given[name].size}" }.to_sentence
    end

    # A step run stands while it hasn't failed or been rejected, took the batch and its picks are still given, and its
    # transformation wasn't saved since it started.
    def stands?(run, batch, sides) = !run.failed? && !run.rejected? && matches?(run, batch, sides) && run.created_at >= run.transformation.updated_at

    # Whether the step run took `batch`, and one item per arrow it picks from that's still given there.
    # `batch` is a Hash of input name => items (see batches_of).
    def matches?(run, batch, sides)
      transformation = run.transformation
      picked = run.sources.select { transformation.picks?(it.item_kind) }
      assigned = run.assigned_inputs.reject { |name, _| transformation.picks?(name) }
      expected = batch.reject { |name, _| transformation.picks?(name) }.transform_values { Array(it) }
      assigned == expected && picked.size == sides.size && picked.zip(sides).all? { |item, given| given.include?(item) }
    end

    # A complete step run of the step's transformation, from any run, that matches and stands, copied into this one
    # with its result shared, so the steps after it reuse theirs too; nil when there's none.
    def reuse(step, batch, sides)
      prior = prior(step, batch, sides) or return
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
        sides = sides_of(from, user)
        batches_of(from, user).each { |batch| runs_of(from).any? { matches?(it, batch, sides) } || reuse(from, batch, sides) }
      end
    end

    # A complete step run of the step's transformation, from any run, that matches and stands.
    # Approval (waits?), Sort (relocates?) and a forwarding step never reuse — every run asks / classifies / posts again.
    def prior(step, batch, sides)
      transformation = step.transformation
      return if transformation.type.waits? || transformation.type.relocates? || transformation.type.forwards?
      transformation.runs.where(status: "complete", created_at: transformation.updated_at..)
        .includes(inputs: :item).find { matches?(it, batch, sides) }
    end

    # Its result goes, unless another step run shares it, and before it the step runs here that took it, as their
    # inputs go with it. A relocating run's result is the source media — never destroy it.
    def drop(run)
      # Relocating and forwarding runs use the source as result — skip self or this recurses forever.
      step_runs.joins(:inputs).where.not(id: run.id)
        .where(transformation_run_inputs: { item_type: run.result_type, item_id: run.result_id }).each { drop(it) }
      if run.transformation&.type&.then { it.relocates? || it.forwards? } || run.result.transformation_runs.many?
        run.destroy!
      else
        run.result.destroy!
      end
    end

    # A step's result moves to its output folder, a media gaining the step's tags.
    # Relocating types already set the folder in `run!`; only tags are applied here.
    def land(result, step)
      return unless result
      return if step.transformation.type.forwards?

      if step.transformation.type.relocates?
        result.update!(tags: result.tags | step.tags) if result.is_a?(LibraryMedia) && step.tags.any?
      else
        result.update!(folder: output_folder(step), **({ tags: result.tags | step.tags } if result.is_a?(LibraryMedia)).to_h)
      end
    end

    # What the arrows into the step give now, by its type's input name, each input only the items that fit it (an
    # image / frame input skips videos). Named ports pin an arrow (`edge.input`); otherwise items match by kind.
    # e.g. { first_frame: [...], last_frame: [...], prompt: [...] }; nil while an arrow gives nothing.
    def given_to(step, user, cached: false)
      transformation = step.transformation
      incoming = edges.select { it.to_id == step.id }.map { |edge| [ edge, output_of(edge.from, user, cached:) ] }
      return if incoming.any? { |_, items| items.empty? }

      given = transformation.inputs.keys.index_with { [] }
      incoming.each do |edge, items|
        name = resolve_input(transformation, edge, items) or next
        given[name].concat(items.select { transformation.fits?(name, it) })
      end
      given.transform_values(&:uniq)
    end

    # The input name an edge feeds: its `input` when set, else the sole fitting input (or :image / :media among roles).
    def resolve_input(transformation, edge, items)
      if edge.input.present?
        name = edge.input.to_sym
        return name if transformation.inputs.key?(name)
      end
      keys = transformation.inputs.keys.select { |name| items.any? { transformation.fits?(name, it) } }
      return keys.first if keys.one?
      keys.find { it.in?(%i[image media video]) } || keys.first
    end

    # What each arrow a step run picks one item of gives, in the order they were connected, e.g. [[shot, ...], [style, ...]].
    def sides_of(step, user, cached: false)
      edges.select { it.to_id == step.id }.filter_map do |edge|
        items = output_of(edge.from, user, cached:)
        items if items.any? && step.transformation.picks?(items.first.item_kind)
      end
    end

    # The items of each step run the step makes from what its arrows give now, its picks aside, as a Hash per input
    # name: a media input of 1 one step run per item, any other input all its items in each. None while an arrow
    # gives nothing or an input gets fewer than it takes; one with no items for a step taking none and given nothing.
    def batches_of(step, user, cached: false)
      transformation = step.transformation
      given = given_to(step, user, cached:) or return []
      return [] if transformation.inputs.any? { |kind, count| given[kind].size < count.begin }
      fixed = given.reject { |kind, _| transformation.picks?(kind) }
      # Fan inputs of 1 (one step run per item); skip empty optional ones so a free End doesn't wipe Start's batches.
      fans = fixed.keys.select { |name| transformation.inputs[name].end == 1 && fixed[name].any? }
      runs = fans.reduce([ {} ]) { |acc, kind| acc.flat_map { |run| fixed[kind].map { run.merge(kind => [ it ]) } } }
      runs.map { |run| fixed.to_h { |kind, items| [ kind, run[kind] || items ] } }
    end

    # A node's output in this run: a folder what's picked of it, a media itself, a step what its step runs made, in its
    # batches' order, once they're all complete. `cached` counts a batch's prior step run (see gives); running never
    # does, or a rerun! step's old result would start the steps after it.
    def output_of(node, user, cached: false)
      if node.step?
        runs, sides = runs_of(node).select(&:complete?), sides_of(node, user, cached:)
        made = batches_of(node, user, cached:).map do |batch|
          run = runs.find { matches?(it, batch, sides) } || (prior(node, batch, sides) if cached)
          run&.transformation&.type&.forwards? ? run.sources.presence : run&.result
        end
        made.all? ? made.flatten : []
      elsif node.library_media then [ node.library_media ]
      else picked(node, user)
      end
    end

    # The step's first output folder, else Ready for what it makes.
    def output_folder(step)
      edges.find { it.from_id == step.id && !it.to.step? }&.to&.folder || Folder.ready(step.transformation.makes)
    end

    # The result, with the step's tags, lands in its output folder. Each side gives one pick: a prompt at random, the
    # newest review.
    def start_step(step, batch, sides, user)
      picks = sides.map { it.first.is_a?(Prompt) ? it.sample : it.first }
      named = batch.transform_values { Array(it) }
      picks.each do |item|
        name = step.transformation.inputs.keys.find { |n| step.transformation.picks?(n) && step.transformation.fits?(n, item) }
        named[name] = named.fetch(name, []) + [ item ] if name
      end
      step.transformation.run!(items: named, user:, folder: output_folder(step), tags: step.tags, workflow_run: self, workflow_node: step)
    rescue ActiveRecord::RecordInvalid => e
      update!(error: "#{step.label}: #{e.record.errors.full_messages.to_sentence}")
    end
end
