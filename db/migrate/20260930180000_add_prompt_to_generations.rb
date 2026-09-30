class AddPromptToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :prompt, :text
  end
end
