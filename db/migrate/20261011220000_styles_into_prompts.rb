# frozen_string_literal: true

# Styles become shared prompts in Prompts / Styles, their examples with them; a step gets a style from a prompt folder
# feeding it instead of a fixed one.
class StylesIntoPrompts < ActiveRecord::Migration[8.1]
  class Folder < ActiveRecord::Base; end
  class Prompt < ActiveRecord::Base; end

  def up
    now = Time.current
    root = Folder.find_by!(parent_id: nil, slug: "prompts")
    folder = Folder.create!(name: "Styles", slug: "styles", color: root.color, kind: "prompt", parent_id: root.id, created_at: now, updated_at: now)
    select_rows("SELECT id, name, body FROM styles ORDER BY name").each do |id, name, body|
      prompt = Prompt.create!(folder_id: folder.id, name:, body:, created_at: now, updated_at: now)
      execute "UPDATE active_storage_attachments SET record_type = 'Prompt', record_id = #{prompt.id} WHERE record_type = 'Style' AND record_id = #{id}"
    end

    remove_reference :transformations, :style, foreign_key: { on_delete: :nullify }, index: true
    remove_reference :transformation_runs, :style, foreign_key: { on_delete: :nullify }, index: true
    drop_table :styles
  end

  def down = raise ActiveRecord::IrreversibleMigration
end
