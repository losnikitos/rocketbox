# frozen_string_literal: true

module Accounts
  class RecipesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_recipe, only: %i[edit update destroy destroy_example]

    def index
      @recipes = Recipe.with_attached_examples.ordered
    end

    def new
      @recipe = Recipe.new
    end

    def create
      @recipe = Recipe.new(recipe_params)
      if @recipe.save
        redirect_to recipes_path, notice: "Recipe added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @recipe.update(recipe_params)
        redirect_to recipes_path, notice: "Recipe saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @recipe.destroy!
      redirect_to recipes_path, notice: "Recipe removed."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to recipes_path, alert: "This recipe is used by posts and can't be removed."
    end

    def destroy_example
      @recipe.examples.find(params[:example_id]).purge_later
      redirect_to edit_recipe_path(@recipe), notice: "Example removed."
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:id])
      end

      def recipe_params
        params.expect(recipe: [ :name, :prompt, :media_type, examples: [] ])
      end
  end
end
