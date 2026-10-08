# frozen_string_literal: true

module Accounts
  # A workflow's page draws its graph and edits it: each add, connect and remove form submits nested attributes to update.
  class WorkflowsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_workflow, only: %i[show update destroy]

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
      if @workflow.update(workflow_params)
        redirect_to workflow_path(@workflow), notice: "Workflow saved."
      else
        set_graph
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @workflow.destroy!
      redirect_to workflows_path, notice: "Workflow deleted."
    end

    private

      def set_workflow
        @workflow = Workflow.find(params[:id])
      end

      def workflow_params
        params.expect(workflow: [ :name, nodes_attributes: [ [ :id, :kind, :folder_id, :transformation_id, :_destroy ] ],
                                         edges_attributes: [ [ :id, :from_id, :to_id, :_destroy ] ] ])
      end

      # Saved nodes and edges only, so a rejected edit doesn't draw.
      def set_graph
        nodes = @workflow.nodes.select(&:persisted?)
        @nodes = nodes.to_h do |node|
          path = node.step? ? transformation_path(node.transformation) : library_folders_path(*[ node.folder.parent&.slug, node.folder.slug ].compact)
          icon = { "input" => "inbox", "output" => "photo" }[node.kind]
          [ "node-#{node.id}", { label: node.label, icon:, path:, shape: node.step? ? :recipe : :folder, color: node.folder&.color } ]
        end
        @edges = @workflow.edges.select(&:persisted?).map { [ "node-#{it.from_id}", "node-#{it.to_id}" ] }
      end
  end
end
