class ReplaceMediaTypeWithRecipeOnFeatureSettings < ActiveRecord::Migration[8.1]
  def change
    remove_reference :feature_settings, :media_type, foreign_key: { on_delete: :nullify }, index: true
    add_reference :feature_settings, :recipe, foreign_key: { on_delete: :nullify }
  end
end
