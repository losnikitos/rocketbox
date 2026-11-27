# frozen_string_literal: true

class RestructureGuideChaptersAndCreateGuideRules < ActiveRecord::Migration[8.1]
  def change
    change_table :guide_chapters, bulk: true do |t|
      t.remove :body, type: :text, default: "", null: false
      t.text :lede, null: false, default: ""
    end

    create_table :guide_rules do |t|
      t.references :guide, null: false, foreign_key: true
      t.references :guide_chapter, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :guide_rules, %i[guide_id number], unique: true
  end
end
