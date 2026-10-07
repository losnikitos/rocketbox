# frozen_string_literal: true

# A recipe's inputs become one per folder with a count: two inputs from one folder merge into one taking two.
class CountRecipeInputs < ActiveRecord::Migration[8.1]
  def up
    select_rows("SELECT id, inputs FROM recipes").each do |id, inputs|
      merged = JSON.parse(inputs).group_by { it["folder_id"] }.map { |folder_id, slots| { "folder_id" => folder_id, "count" => slots.size } }
      execute "UPDATE recipes SET inputs = #{quote(merged.to_json)} WHERE id = #{id}"
    end
  end

  def down = raise(ActiveRecord::IrreversibleMigration)
end
