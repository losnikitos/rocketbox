# frozen_string_literal: true

class MonitorMediaGenerationsController < ApplicationController
  layout "monitor"
  before_action :authenticate_admin!

  def index
    @media_generation = MediaGeneration.new(model: MediaGeneration::MEDIA_MODELS["image"].first)
    @media_generations = MediaGeneration.order(created_at: :desc).limit(50)
  end

  def new
    redirect_to monitor_media_generations_path
  end

  def show
    @media_generation = MediaGeneration.find(params[:id])
  end

  def create
    @media_generation = MediaGeneration.new(media_generation_params)
    @media_generation.user = Current.user
    @media_generation.status = :in_progress

    if @media_generation.save
      RunMediaGenerationJob.perform_later(@media_generation.id)
      redirect_to monitor_media_generation_path(@media_generation), notice: "Generation started."
    else
      @media_generations = MediaGeneration.order(created_at: :desc).limit(50)
      render :index, status: :unprocessable_entity
    end
  end

  private

    def media_generation_params
      params.require(:media_generation).permit(:model, :prompt)
    end
end
