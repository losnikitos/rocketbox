# frozen_string_literal: true

module Accounts
  # A workflow's page is a canvas editor: adding, connecting, moving and removing nodes all submit nested attributes to
  # update. `?node=` or `?edge=` selects a node or connection for the inspector. `?run=` is run mode: the run's step runs
  # replace the palette and the inspector shows the selected node's inputs and outputs in the run. Play on a start folder (run) replays the draft run from it;
  # run again on a step reruns it (see WorkflowRun).
  class WorkflowsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_workflow, only: %i[show update destroy run copy]

    def index
      @workflows = Workflow.includes(:nodes).order(updated_at: :desc)
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
      draft = @workflow.draft_run
      node.step? ? draft.rerun!(node, Current.account) : draft.start!(node, Current.account)
      redirect_to workflow_path(@workflow, run: draft.id)
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
        params.expect(workflow: [ :name, nodes_attributes: [ [ :id, :folder_id, :library_media_id, :tag_id, :x, :y, :_destroy, transformation_attributes: [ :kind ] ] ],
                                         edges_attributes: [ [ :id, :from_id, :to_id, :_destroy ] ] ])
      end

      # Saved nodes and edges only, so a rejected edit doesn't draw.
      def set_graph
        @run = @workflow.runs.find_by(id: params[:run])
        @step_runs = @run.step_runs.includes(:workflow_node, :transformation, inputs: { library_media: { file_attachment: :blob } },
          generated_media: { file_attachment: :blob }) if @run
        @graph_nodes = @workflow.nodes.select(&:persisted?)
        @graph_edges = @workflow.edges.select(&:persisted?)
        @selected = @graph_nodes.find { it.id == params[:node].to_i }
        @selected_edge = @graph_edges.find { it.id == params[:edge].to_i }
        if @selected&.folder
          @folder_media = Current.account.library_media.where(folder: @selected.folder).with_attached_file
            .includes(:transformation_run).order(created_at: :desc)
          @folder_media = @folder_media.where(id: @selected.tag.library_media) if @selected.tag
        end
        # In run mode, what the selected node took and gave in the run: a step its step run's sources and result, a
        # folder what the step runs feeding it made and what of it the step runs it feeds took (a media node only the latter).
        if @run && @selected
          @step_run = @step_runs.find { it.workflow_node_id == @selected.id }
          linked = ->(from, to) { @graph_edges.any? { it.from_id == from && it.to_id == to } }
          @run_inputs, @run_outputs = if @selected.step?
            [ @step_run&.source_media.to_a, [ @step_run&.generated_media ].compact ]
          else
            [ @step_runs.select { linked.(it.workflow_node_id, @selected.id) }.map(&:generated_media),
              @step_runs.select { linked.(@selected.id, it.workflow_node_id) }.flat_map(&:source_media)
                .select { @selected.library_media ? it == @selected.library_media : it.folder_id == @selected.folder_id }.uniq ]
          end
        end
        # Start folders feed steps and nothing feeds them.
        @start_nodes = @graph_nodes.select { |node| node.folder && @graph_edges.any? { it.from_id == node.id } && @graph_edges.none? { it.to_id == node.id } }
        @nodes = @graph_nodes.to_h do |node|
          icon = @graph_edges.any? { it.from_id == node.id } ? "inbox" : "photo" if node.folder
          shape = node.step? ? :step : node.library_media ? :media : :folder
          step_run = @step_runs&.find { it.workflow_node_id == node.id }
          [ node.id, { label: node.label, icon:, cover: node.transformation&.cover, media: node.library_media, path: workflow_path(@workflow, node: node.id, run: @run&.id), frame: "inspector",
                       current: node == @selected, linkable: true, x: node.x, y: node.y, shape:, color: node.folder&.color,
                       kind: node.transformation&.type_label, inputs: @graph_edges.count { it.to_id == node.id }, play: @start_nodes.include?(node),
                       status: step_run&.status, error: step_run&.error, rerun: (step_run && !step_run.running?) } ]
        end
        @edges = @graph_edges.map { [ it.from_id, it.to_id, { id: it.id, path: workflow_path(@workflow, edge: it.id, run: @run&.id), frame: "inspector", current: it == @selected_edge } ] }
      end
  end
end
