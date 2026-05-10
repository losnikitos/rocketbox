# frozen_string_literal: true

class SyncBookChaptersFromNotionJob < ApplicationJob
  queue_as :default

  def perform(book_id = nil)
    scope = Book.where.not(notion_database_id: nil)
    scope = scope.where(id: book_id) if book_id
    scope.find_each { |book| Notion::ChapterSync.call(book: book) }
  end
end
