# frozen_string_literal: true

module Accounts
  # A workflow step's transformation, edited in the workflow's inspector frame; a model change resubmits the form as a
  # GET to redraw it. Outside the frame it opens the step on its workflow.
  class TransformationsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_transformation, only: %i[show update]

    def show
      unless turbo_frame_request?
        node = @transformation.workflow_nodes.includes(:workflow).first or raise ActiveRecord::RecordNotFound
        return redirect_to workflow_path(node.workflow, node: node.id)
      end

      @transformation.assign_attributes(draft_params)
      @transformation.fill_options
    end

    def update
      @transformation.assign_attributes(transformation_params)
      @transformation.fill_options
      if @transformation.save
        return render turbo_stream: node_streams if autosave_request?

        redirect_to transformation_path(@transformation), notice: "Transformation saved."
      else
        return render_autosave_error(@transformation) if autosave_request?

        render :show, status: :unprocessable_entity
      end
    end

    # The reel a scripted type is cut from, previewed on the form.
    def original
      original = Transformation::Type.find(params[:kind]).try(:original)
      return head :not_found unless original

      send_file original, type: "video/mp4", disposition: "inline"
    end

    private

      def set_transformation
        @transformation = Transformation.find(params[:id])
      end

      def transformation_params
        params.expect(transformation: [ :name, :body, :prompt_folder, :style_id, layer_steps: [ Layer::ALL.flat_map { it.fields.map(&:name) }.uniq ], options: {} ])
      end

      def draft_params = params[:transformation] ? transformation_params : {}

      # Its step's node on the canvas shows the saved name and options.
      def node_streams
        @transformation.workflow_nodes.flat_map do |node|
          { label: @transformation.name, kind: @transformation.options_label }
            .map { |part, text| turbo_stream.update("node_#{node.id}_#{part}", text) }
        end
      end
  end
end
