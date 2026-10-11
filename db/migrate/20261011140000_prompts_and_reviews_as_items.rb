# frozen_string_literal: true

# Media, prompts and reviews become items: each in a folder of one table (its `kind` says which), and step runs take
# and make any of them (polymorphic inputs and results). Prompt folders become folder nodes, wired in by edges.
class PromptsAndReviewsAsItems < ActiveRecord::Migration[8.1]
  class Folder < ActiveRecord::Base; end

  def up
    add_column :folders, :kind, :string, default: "media", null: false
    now = Time.current
    root = ->(slug, color, kind) { Folder.create!(name: slug.humanize, slug:, color:, kind:, created_at: now, updated_at: now) }
    prompts, reviews = root.("prompts", "violet", "prompt"), root.("reviews", "amber", "review")
    names = select_values("SELECT DISTINCT folder FROM prompts") | [ "Ready" ]
    children = names.to_h do |name|
      [ name, Folder.create!(name:, slug: name.parameterize, color: "violet", kind: "prompt", parent_id: prompts.id, created_at: now, updated_at: now) ]
    end

    add_reference :prompts, :folder, foreign_key: true
    children.each { |name, folder| execute "UPDATE prompts SET folder_id = #{folder.id} WHERE folder = #{connection.quote(name)}" }
    change_column_null :prompts, :folder_id, false
    remove_column :prompts, :folder
    add_reference :prompts, :user, foreign_key: true

    add_reference :reviews, :folder, foreign_key: true
    execute "UPDATE reviews SET folder_id = #{reviews.id}"
    change_column_null :reviews, :folder_id, false

    add_reference :transformation_run_inputs, :item, polymorphic: true
    execute "UPDATE transformation_run_inputs SET item_type = 'LibraryMedia', item_id = library_media_id"
    remove_foreign_key :transformation_run_inputs, :library_media
    remove_column :transformation_run_inputs, :library_media_id
    [ [ "prompt_id", "Prompt" ], [ "review_id", "Review" ] ].each do |column, type|
      execute <<~SQL
        INSERT INTO transformation_run_inputs (transformation_run_id, position, item_type, item_id)
        SELECT id, (SELECT COALESCE(MAX(position), -1) + 1 FROM transformation_run_inputs i WHERE i.transformation_run_id = transformation_runs.id), '#{type}', #{column}
        FROM transformation_runs WHERE #{column} IS NOT NULL
      SQL
    end
    change_column_null :transformation_run_inputs, :item_type, false
    change_column_null :transformation_run_inputs, :item_id, false

    add_reference :transformation_runs, :result, polymorphic: true
    execute "UPDATE transformation_runs SET result_type = 'LibraryMedia', result_id = generated_media_id"
    change_column_null :transformation_runs, :result_type, false
    change_column_null :transformation_runs, :result_id, false
    remove_foreign_key :transformation_runs, column: :generated_media_id
    remove_foreign_key :transformation_runs, :prompts
    remove_foreign_key :transformation_runs, :reviews
    remove_column :transformation_runs, :generated_media_id
    remove_column :transformation_runs, :prompt_id
    remove_column :transformation_runs, :review_id

    select_rows(<<~SQL).each do |id, workflow_id, x, y, name|
      SELECT n.id, n.workflow_id, n.x, n.y, t.prompt_folder FROM workflow_nodes n
      JOIN transformations t ON t.id = n.transformation_id WHERE t.prompt_folder IS NOT NULL
    SQL
      folder = children[name] or next
      node = insert("INSERT INTO workflow_nodes (workflow_id, folder_id, x, y, created_at, updated_at) VALUES (#{workflow_id}, #{folder.id}, #{x - 300}, #{y + 150}, #{connection.quote(now)}, #{connection.quote(now)})")
      execute "INSERT INTO workflow_edges (workflow_id, from_id, to_id, created_at, updated_at) VALUES (#{workflow_id}, #{node}, #{id}, #{connection.quote(now)}, #{connection.quote(now)})"
    end
    remove_column :transformations, :prompt_folder
  end

  def down = raise ActiveRecord::IrreversibleMigration
end
