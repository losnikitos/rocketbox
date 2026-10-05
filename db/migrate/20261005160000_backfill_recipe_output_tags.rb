class BackfillRecipeOutputTags < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE recipes SET output_tag_id = CAST(json_extract(inputs, '$[0].tag_id') AS INTEGER)
      WHERE output_tag_id IS NULL AND json_extract(inputs, '$[0].tag_id') IN (SELECT id FROM tags)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
