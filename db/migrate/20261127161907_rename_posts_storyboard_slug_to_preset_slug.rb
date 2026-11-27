# frozen_string_literal: true

class RenamePostsStoryboardSlugToPresetSlug < ActiveRecord::Migration[8.1]
  def change
    rename_column :posts, :storyboard_slug, :preset_slug
  end
end
