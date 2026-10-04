class MakeGenerationPromptOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :generations, :prompt_id, true
  end
end
