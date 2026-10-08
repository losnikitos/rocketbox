class AddAutorunToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_column :workflows, :autorun, :boolean, default: false, null: false
  end
end
