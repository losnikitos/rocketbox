# frozen_string_literal: true

class RemoveNameFromPosts < ActiveRecord::Migration[8.1]
  def change
    remove_column :posts, :name, :string, null: false, default: ""
  end
end
