# frozen_string_literal: true

module Accounts
  class OverviewController < ApplicationController
    layout "app"

    # How media flows: recipes read from folders and write to a folder.
    # Styles, shot groups, layers and reviews are drawn as folders too. Recipe links are admin-only.
    def show
      recipes = Recipe.includes(transformation: :style).ordered
      folders = Folder.includes(:parent).where(id: recipes.flat_map { [ *it.folder_ids, it.output_folder_id ] }).index_by(&:id)
      admin = Current.user.admin?
      @nodes, @edges = {}, []
      node = ->(id, label, icon, path, shape = :folder, color: nil) { @nodes[id] ||= { label:, icon:, path:, shape:, color: }; id }
      folder = ->(f) { node.("folder-#{f.id}", f.path, f.root.slug == "inbox" ? "inbox" : "photo", library_folders_path(*[ f.parent&.slug, f.slug ].compact), color: f.color) }

      recipes.each do |recipe|
        id = node.("recipe-#{recipe.id}", recipe.name, nil, (recipe_path(recipe) if admin), :recipe)
        inputs = recipe.folder_ids.uniq.filter_map { folders[it] }.map(&folder)
        inputs << node.("style-#{recipe.style.id}", recipe.style.name, "swatch", (styles_path if admin)) if recipe.style
        inputs << node.("shot-#{recipe.shot_group}", recipe.shot_group, "camera", (shots_path if admin)) if recipe.shot_group
        inputs << node.("layer-#{recipe.layer.slug}", recipe.layer.name, "square-3-stack-3d", (layer_path(recipe.layer) if admin)) if recipe.layer
        inputs << node.("reviews", "Reviews", "star", reviews_path) if recipe.takes_review?
        output = folders[recipe.output_folder_id]&.then(&folder)
        @edges.concat(inputs.map { [ it, id ] })
        @edges << [ id, output ] if output
      end
    end
  end
end
