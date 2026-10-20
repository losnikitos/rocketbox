# frozen_string_literal: true

class BackfillSortTransformationPrompt < ActiveRecord::Migration[8.1]
  def up
    Transformation.where(kind: "sort").find_each do |transformation|
      next if transformation.body.present?

      transformation.update!(body: Transformation::Sort::DEFAULT_BODY)
    end
  end

  def down
    # Keep edited prompts.
  end
end
