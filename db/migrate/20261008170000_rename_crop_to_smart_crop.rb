# frozen_string_literal: true

# The crop type is now smart crop: it places the crop around the subject instead of the middle.
class RenameCropToSmartCrop < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE transformations SET name = 'Smart crop' WHERE kind = 'crop' AND name = 'Crop'"
    execute "UPDATE transformations SET kind = 'smart_crop' WHERE kind = 'crop'"
  end

  def down
    execute "UPDATE transformations SET name = 'Crop' WHERE kind = 'smart_crop' AND name = 'Smart crop'"
    execute "UPDATE transformations SET kind = 'crop' WHERE kind = 'smart_crop'"
  end
end
