class SingleRecipeExample < ActiveRecord::Migration[8.1]
  def up
    ActiveStorage::Attachment.where(record_type: "Recipe", name: "examples").includes(:blob).order(:id).group_by(&:record_id).each_value do |attachments|
      kept = attachments.find(&:image?)
      kept&.update_columns(name: "example")
      (attachments - [ kept ]).each(&:purge_later)
    end
  end

  def down = raise ActiveRecord::IrreversibleMigration
end
