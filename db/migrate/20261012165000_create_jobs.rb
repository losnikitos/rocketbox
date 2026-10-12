# frozen_string_literal: true

class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :jobs, %i[user_id slug], unique: true
    add_reference :library_media, :job, foreign_key: true
  end
end
