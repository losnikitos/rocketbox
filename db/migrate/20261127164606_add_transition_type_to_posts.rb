# frozen_string_literal: true

class AddTransitionTypeToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :transition_type, :string, null: false, default: "simple_fade"
  end
end
