class CreateSmmSlides < ActiveRecord::Migration[8.1]
  def up
    create_table :smm_slides do |t|
      t.references :smm_post, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_column :smm_posts, :format, :string, null: false, default: "reel"
    remove_column :smm_posts, :generation_request_id

    execute <<~SQL
      INSERT INTO smm_slides (smm_post_id, position, created_at, updated_at)
      SELECT record_id, 0, created_at, created_at FROM active_storage_attachments
      WHERE record_type = 'SmmPost' AND name = 'generated_video'
    SQL
    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'SmmSlide', name = 'media',
          record_id = (SELECT id FROM smm_slides WHERE smm_slides.smm_post_id = active_storage_attachments.record_id)
      WHERE record_type = 'SmmPost' AND name = 'generated_video'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
