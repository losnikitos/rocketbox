# frozen_string_literal: true

module Accounts
  class RubricsController < ApplicationController
    layout "app"

    before_action :set_rubric, only: %i[edit update destroy]
    before_action :set_calendar, only: %i[index new edit]

    def index
    end

    # new and edit take unsaved rubric params too: the form's Preview button GETs them back to draw the calendar.
    def new
      @rubric = Current.account.rubrics.new(folder: Folder.ready)
      preview
    end

    def create
      @rubric = Current.account.rubrics.new(rubric_params)
      if @rubric.save
        redirect_to rubrics_path, notice: "Rubric added."
      else
        set_calendar
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      preview
    end

    def update
      if @rubric.update(rubric_params)
        redirect_to rubrics_path, notice: "Rubric saved."
      else
        set_calendar
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @rubric.destroy!
      redirect_to rubrics_path, notice: "Rubric removed."
    end

    private

      def set_rubric
        @rubric = Current.account.rubrics.find(params[:id])
      end

      def preview
        return unless params[:rubric]

        @rubric.assign_attributes(rubric_params)
        @rubric.validate
      end

      def set_calendar
        @date = (Date.iso8601(params[:date].to_s) rescue Date.current)
        @week = params[:view] != "month"
        @days = @week ? @date.all_week : @date.beginning_of_month.beginning_of_week..@date.end_of_month.end_of_week
        @rubrics = Current.account.rubrics.includes(:folder).order(:created_at)
        @posts = RubricPost.where(rubric: @rubrics, created_at: @days.first.beginning_of_day..@days.last.end_of_day)
          .includes(:rubric, library_media: { file_attachment: :blob })
      end

      def rubric_params
        params.expect(rubric: %i[name schedule format folder_id color auto_publish])
      end
  end
end
