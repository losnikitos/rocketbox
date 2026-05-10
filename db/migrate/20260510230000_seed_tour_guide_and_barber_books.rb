# frozen_string_literal: true

class SeedTourGuideAndBarberBooks < ActiveRecord::Migration[8.1]
  class Book < ActiveRecord::Base
    self.table_name = "books"
    has_many :chapters, class_name: "SeedTourGuideAndBarberBooks::Chapter", foreign_key: :book_id, inverse_of: :book, dependent: :destroy
  end

  class Chapter < ActiveRecord::Base
    self.table_name = "chapters"
    belongs_to :book, class_name: "SeedTourGuideAndBarberBooks::Book", inverse_of: :chapters
  end

  TOUR_GUIDE_CHAPTERS = [
    "Bookings, calendars, and no-shows",
    "Safety, permits, and liability basics",
    "Storytelling that earns five-star reviews",
    "Running a standout group experience",
  ].freeze

  BARBER_CHAPTERS = [
    "Chair flow, wait times, and the board",
    "Retail, upsells, and product rotation",
    "Retention, reminders, and VIP cuts",
    "Building a shop people return to",
  ].freeze

  def up
    seed_book_if_missing(
      slug: "tour-guide",
      title: "The Tour Guide Operator’s Playbook",
      chapter_titles: TOUR_GUIDE_CHAPTERS,
    )
    seed_book_if_missing(
      slug: "barber",
      title: "The Barber Shop Operator’s Playbook",
      chapter_titles: BARBER_CHAPTERS,
    )
  end

  def down
    Book.find_by(slug: "tour-guide")&.destroy!
    Book.find_by(slug: "barber")&.destroy!
  end

  private

    def seed_book_if_missing(slug:, title:, chapter_titles:)
      return if Book.exists?(slug:)

      book = Book.create!(title:, slug:)
      chapter_titles.each_with_index do |chapter_title, index|
        book.chapters.create!(title: chapter_title, position: index + 1)
      end
    end
end
