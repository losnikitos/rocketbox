# frozen_string_literal: true

module Accounts
  class ShotsController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_shot, only: %i[edit update destroy]

    def index
      @shots = Shot.with_attached_examples.ordered
      @shots = @shots.where(group: params[:group]) if params[:group].present?
    end

    def new
      @shot = Shot.new(params.permit(:group).compact_blank)
    end

    def create
      @shot = Shot.new(shot_params)
      if @shot.save
        redirect_to shots_path(group: @shot.group), notice: "Shot added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @shot.update(shot_params)
        redirect_to shots_path(group: @shot.group), notice: "Shot saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @shot.destroy!
      redirect_to shots_path(group: @shot.group), notice: "Shot removed."
    end

    private

      def set_shot
        @shot = Shot.find(params[:id])
      end

      def shot_params
        params.expect(shot: [ :name, :group, :body, examples: [] ])
      end
  end
end
