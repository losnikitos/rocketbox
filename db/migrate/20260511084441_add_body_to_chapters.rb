class AddBodyToChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :chapters, :body, :text, null: false, default: ""
  end
end
