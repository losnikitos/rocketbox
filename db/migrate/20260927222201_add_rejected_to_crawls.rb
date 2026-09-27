class AddRejectedToCrawls < ActiveRecord::Migration[8.1]
  def change
    add_column :crawls, :rejected, :json, default: [], null: false
  end
end
