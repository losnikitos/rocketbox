# frozen_string_literal: true

module Accounts
  # The draft screen between picking a recipe and running it: an unsaved Generation with its AI options.
  class GenerationsController < ApplicationController
    layout "app"

    before_action :set_generation

    def new
    end

    def create
      @generation.options = params.expect(generation: [ options: {} ])[:options].to_h
      @generation.start!
      redirect_to helpers.library_item_path(@generation.generated_media), notice: "Applying #{@generation.recipe.name}…"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

      def set_generation
        media = Current.account.library_media.with_attached_file.find(params[:library_media_id])
        recipe = media.recipes.find { it.id == params[:recipe_id].to_i }
        return redirect_to helpers.library_item_path(media), alert: "That recipe doesn't fit this media." unless recipe

        @generation = media.generations.new(recipe:, prompt: params.dig(:generation, :prompt),
          options: params.dig(:generation, :options)&.permit!.to_h || {})
      end
  end
end
