# frozen_string_literal: true

# Which Type.inputs key this item filled (e.g. first_frame / last_frame / reference); blank for legacy greedy runs.
class AddInputToTransformationRunInputs < ActiveRecord::Migration[8.1]
  def change
    add_column :transformation_run_inputs, :input, :string, null: false, default: ""
  end
end
