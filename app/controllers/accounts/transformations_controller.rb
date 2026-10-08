# frozen_string_literal: true

module Accounts
  # A transformation's page edits it inline; a model change resubmits the form as a GET to redraw it.
  # Its type is picked before `new` (`transformation[kind]`) and fixed from then on.
  class TransformationsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_transformation, only: %i[show update destroy]

    def index
      @transformations = Transformation.includes(:style, :recipes).order(updated_at: :desc)
      @transformations = @transformations.where(kind: params[:kind]) if params[:kind].present?
      @run_counts = TransformationRun.group(:transformation_id).count
    end

    def new
      @transformation = Transformation.new(draft_params)
    end

    def create
      @transformation = Transformation.new(transformation_params)
      if @transformation.save
        redirect_to transformation_path(@transformation), notice: "Transformation added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @transformation.assign_attributes(draft_params)
      @transformation.fill_options
    end

    def update
      if @transformation.update(transformation_params)
        redirect_to transformation_path(@transformation), notice: "Transformation saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      if @transformation.destroy
        redirect_to transformations_path, notice: "Transformation deleted."
      else
        redirect_back_or_to transformation_path(@transformation), alert: @transformation.errors.full_messages.to_sentence
      end
    end

    private

      def set_transformation
        @transformation = Transformation.find(params[:id])
      end

      def transformation_params
        params.expect(transformation: [ :name, :kind, :body, :shot_group, :style_id, layer_steps: [ Layer::ALL.flat_map { it.fields.map(&:name) }.uniq ], options: {} ])
      end

      def draft_params = params[:transformation] ? transformation_params : {}
  end
end
