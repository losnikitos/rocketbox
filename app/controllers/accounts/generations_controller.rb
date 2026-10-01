# frozen_string_literal: true

module Accounts
  # The draft screen between picking a prompt and running it: an unsaved Generation with its AI options.
  class GenerationsController < ApplicationController
    layout "app"

    before_action :set_generation

    def new
    end

    def create
      @generation.options = params.expect(generation: [ options: {} ])[:options].to_h
      @generation.start!
      redirect_to helpers.library_item_path(@generation.generated_media), notice: "Applying #{@generation.prompt.name}…"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

      def set_generation
        media = Current.account.library_media.with_attached_file.find(params[:library_media_id])
        prompt = media.prompts.find { it.id == params[:prompt_id].to_i }
        return redirect_to helpers.library_item_path(media), alert: "That prompt doesn't fit this media." unless prompt

        @generation = media.generations.new(prompt:, extra_prompt: params.dig(:generation, :extra_prompt),
          options: params.dig(:generation, :options)&.permit!.to_h || {})
      end
  end
end
