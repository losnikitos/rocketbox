class SlimPrompts < ActiveRecord::Migration[8.1]
  def change
    remove_index :prompts, :active
    remove_index :prompts, :position
    remove_column :prompts, :active, :boolean, default: true, null: false
    remove_column :prompts, :position, :integer, default: 0, null: false
    remove_column :prompts, :name, :string, null: false
    change_column_null :prompts, :key, false
  end
end
