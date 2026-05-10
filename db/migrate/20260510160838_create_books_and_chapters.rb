# frozen_string_literal: true

class CreateBooksAndChapters < ActiveRecord::Migration[8.1]
  class Book < ActiveRecord::Base
    self.table_name = "books"
    has_many :chapters, class_name: "CreateBooksAndChapters::Chapter", foreign_key: :book_id, inverse_of: :book, dependent: :destroy
  end

  class Chapter < ActiveRecord::Base
    self.table_name = "chapters"
    belongs_to :book, class_name: "CreateBooksAndChapters::Book", inverse_of: :chapters
  end

  COFFEESHOP_CHAPTERS = [
    "Why this guide exists",
    "The morning rush in one page",
    "Designing a drinks menu that earns",
    "Dialing in espresso every day",
    "Alternative milks without chaos",
    "Pastry and grab-and-go basics",
    "Cleaning that doesn’t eat the shift",
    "Hiring baristas who stay",
    "Scheduling around peaks",
    "Training tasters, not memorizers",
    "Cash, tips, and fairness",
    "Suppliers and costing coffee",
    "Managing inventory shrink",
    "Preventive maintenance you’ll actually do",
    "Acoustics, seating, and Wi‑Fi policy",
    "Local marketing without a billboard",
    "Handling complaints at the bar",
    "Seasonal menus and limited drops",
    "Expanding hours (or saying no)",
    "Your next 30 days",
  ].freeze

  def up
    create_table :books do |t|
      t.string :title, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :books, :slug, unique: true

    create_table :chapters do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :title, null: false

      t.timestamps
    end
    add_index :chapters, [:book_id, :position], unique: true

    say_with_time "Populate Coffee Shop playbook" do
      coffee = Book.create!(
        title: "The Coffee Shop Operator’s Playbook",
        slug: "coffeeshop",
      )
      COFFEESHOP_CHAPTERS.each_with_index do |title, index|
        coffee.chapters.create!(title:, position: index + 1)
      end
    end
  end

  def down
    drop_table :chapters
    drop_table :books
  end
end
