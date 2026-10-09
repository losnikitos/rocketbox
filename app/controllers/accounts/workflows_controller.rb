# frozen_string_literal: true

module Accounts
  # A workflow's page is a canvas editor: adding, connecting, moving and removing nodes all submit nested attributes to
  # update. `?node=` or `?edge=` selects a node or connection for the inspector. The runs are listed below the canvas, each
  # with its step runs; `?run=` selects one (the latest by default), highlighted, whose step runs the canvas shows, and the
  # inspector shows the selected node's inputs and outputs in it above its settings. Play on a start folder or media (run)
  # replays the selected run from it; play on a step whose feeding steps are complete in the run starts it there, or reruns it (see WorkflowRun).
  class WorkflowsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_workflow, only: %i[show update destroy run copy]

    def index
      @workflows = Workflow.includes(runs: :step_runs).order(updated_at: :desc)
    end

    def new
      @workflow = Workflow.new
    end

    def create
      @workflow = Workflow.new(workflow_params)
      if @workflow.save
        redirect_to workflow_path(@workflow), notice: "Workflow added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      set_graph
    end

    def update
      saved = @workflow.update(workflow_params)
      respond_to do |format|
        format.json { saved ? head(:no_content) : render(json: { error: @workflow.errors.full_messages.to_sentence }, status: :unprocessable_entity) }
        format.html do
          if saved
            redirect_back_or_to workflow_path(@workflow)
          else
            set_graph
            render :show, status: :unprocessable_entity
          end
        end
      end
    end

    def destroy
      @workflow.destroy!
      redirect_to workflows_path, notice: "Workflow deleted."
    end

    def run
      node = @workflow.nodes.find(params[:node_id])
      run = @workflow.runs.find_by(id: params[:run]) || @workflow.latest_run
      node.step? ? run.rerun!(node, Current.account) : run.start!(node, Current.account)
      redirect_to workflow_path(@workflow, run: run.id)
    end

    # Alt-drag: a copy of the node at x, y, without its connections; a step's copy owns a copy of its transformation.
    def copy
      node = @workflow.nodes.find(params[:node_id])
      copy = node.dup.tap { it.assign_attributes(x: params[:x], y: params[:y], transformation: node.transformation&.dup) }
      copy.save!
      redirect_to workflow_path(@workflow, node: copy.id, run: params[:run].presence)
    end

    private

      def set_workflow
        @workflow = Workflow.find(params[:id])
      end

      def workflow_params
        params.expect(workflow: [ :name, :autorun, nodes_attributes: [ [ :id, :folder_id, :library_media_id, :newest, :note, :color, :x, :y, :_destroy, { tag_ids: [] }, transformation_attributes: [ :kind ] ] ],
                                         edges_attributes: [ [ :id, :from_id, :to_id, :slot, :_destroy ] ] ])
      end

      # Saved nodes and edges only, so a rejected edit doesn't draw.
      def set_graph
        # The runs panel: each run with its step runs, what went in and came out, newest first; there's always one to show.
        @workflow.latest_run
        @runs = @workflow.runs.includes(step_runs: [ :workflow_node, :transformation, { inputs: { library_media: { file_attachment: :blob } } },
          { generated_media: { file_attachment: :blob } } ]).reverse
        @run = @runs.find { it.id == params[:run].to_i } || @runs.first
        @step_runs = @run.step_runs
        @graph_nodes = @workflow.nodes.select(&:persisted?)
        @graph_edges = @workflow.edges.select(&:persisted?)
        @selected = @graph_nodes.find { it.id == params[:node].to_i }
        @selected_edge = @graph_edges.find { it.id == params[:edge].to_i }
        if @selected&.folder
          @folder_media = Current.account.library_media.where(folder: @selected.folder).tagged_all(@selected.tags.ids).with_attached_file
            .includes(:transformation_run).order(created_at: :desc)
        end
        # A step's step runs in the run, one per batch of its inputs (see WorkflowRun).
        runs_of = ->(node) { @step_runs.select { it.workflow_node_id == node.id } }
        # What the selected node took and gave in the run: a step its step runs' sources and results, a folder what the
        # step runs feeding it made and what of it the step runs it feeds took (a media node only the latter).
        if @selected
          @node_runs = runs_of.(@selected)
          linked = ->(from, to) { @graph_edges.any? { it.from_id == from && it.to_id == to } }
          @run_inputs, @run_outputs = if @selected.step?
            [ @node_runs.flat_map(&:source_media).uniq, @node_runs.map(&:generated_media) ]
          else
            [ @step_runs.select { linked.(it.workflow_node_id, @selected.id) }.map(&:generated_media),
              @step_runs.select { linked.(@selected.id, it.workflow_node_id) }.flat_map(&:source_media)
                .select { @selected.library_media ? it == @selected.library_media : it.folder_id == @selected.folder_id }.uniq ]
          end
        end
        @start_nodes = @workflow.start_nodes
        complete = @graph_nodes.select { |node| runs_of.(node).then { it.any? && it.all?(&:complete?) } }.map(&:id)
        @nodes = @graph_nodes.to_h do |node|
          icon = @graph_edges.any? { it.from_id == node.id } ? "inbox" : "photo" if node.folder
          shape = node.step? ? :step : node.note? ? :note : node.library_media ? :media : :folder
          runs = runs_of.(node)
          # A step not running can start once every step feeding it is complete in the run; folders and media always feed.
          feeds = @graph_edges.select { it.to_id == node.id }
          ready = node.step? && runs.none?(&:running?) && feeds.any? &&
            feeds.all? { |edge| @graph_nodes.find { it.id == edge.from_id }.then { !it.step? || complete.include?(it.id) } }
          [ node.id, { label: node.label, icon:, cover: node.transformation&.cover, media: node.library_media, path: workflow_path(@workflow, node: node.id, run: @run.id), frame: "inspector",
                       current: node == @selected, linkable: !node.note?, x: node.x, y: node.y, shape:, note: node.note,
                       color: node.note? ? node.color : node.folder&.color,
                       kind: node.transformation&.options_label, inputs: feeds.size, slots: node.transformation&.slots,
                       play: @start_nodes.include?(node) || (ready && runs.empty?),
                       status: TransformationRun.status_of(runs), error: runs.filter_map(&:error).uniq.join("; ").presence, rerun: (ready && runs.any?) } ]
        end
        # What last went along an edge in the run: a step's result out of it, or what a step took from a folder or media;
        # until a step takes from a folder, what the folder gives in the run (its picks, else its newest).
        by_id = @graph_nodes.index_by(&:id)
        carried = ->(edge) do
          from = by_id[edge.from_id]
          media = if from.step? then runs_of.(from).last&.generated_media
          else runs_of.(by_id[edge.to_id]).last&.source_media&.find { from.library_media ? it == from.library_media : it.folder_id == from.folder_id } ||
            (@run.picked(from, Current.account).first if from.folder)
          end
          media if media&.file&.attached?
        end
        @edges = @graph_edges.map { [ it.from_id, it.to_id, { id: it.id, slot: it.slot, path: workflow_path(@workflow, edge: it.id, run: @run.id), frame: "inspector",
                                                              current: it == @selected_edge, media: carried.(it) } ] }
      end
  end
end
