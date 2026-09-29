class AddSourceToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :source, :string, null: false, default: "google"
    change_column_default :reviews, :source, from: "google", to: nil
  end
end
