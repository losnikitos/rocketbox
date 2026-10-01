# frozen_string_literal: true

module Accounts
  class RecipesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_recipe, only: %i[edit update destroy]

    def index
      @recipes = Recipe.ordered
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
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:id])
      end

      def recipe_params
        params.expect(recipe: [ :name, :format, :body, media_type_ids: [] ])
      end
  end
end
