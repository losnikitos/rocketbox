# frozen_string_literal: true

class AddPromptToGuideRules < ActiveRecord::Migration[8.1]
  def change
    add_column :guide_rules, :prompt, :text, null: false, default: ""
  end
end
