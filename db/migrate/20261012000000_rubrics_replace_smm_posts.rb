# frozen_string_literal: true

class RubricsReplaceSmmPosts < ActiveRecord::Migration[8.1]
  def up
    create_table :rubrics do |t|
      t.references :user, null: false, foreign_key: true
      t.references :folder, null: false, foreign_key: true
      t.string :name, null: false
      t.string :schedule, null: false
      t.string :format, null: false, default: "story"
      t.string :color, null: false, default: "sky"
      t.boolean :auto_publish, null: false, default: false
      t.datetime :next_run_at, index: true
      t.timestamps
    end

    create_table :rubric_posts do |t|
      t.references :rubric, null: false, foreign_key: { on_delete: :cascade }
      t.references :library_media, foreign_key: { on_delete: :nullify }, index: false
      t.datetime :published_at
      t.text :error_message
      t.timestamps
      t.index %i[library_media_id created_at]
    end

    slides = ActiveStorage::Attachment.where(record_type: "SmmSlide")
    blob_ids = slides.pluck(:blob_id)
    slides.delete_all
    ActiveStorage::Blob.where(id: blob_ids).find_each(&:purge_later)

    drop_table :smm_slides
    drop_table :smm_post_media_items
    drop_table :smm_posts
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
