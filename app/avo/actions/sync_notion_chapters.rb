# frozen_string_literal: true

class Avo::Actions::SyncNotionChapters < Avo::BaseAction
  self.name = "Sync Notion Chapters"
  self.message = "Start syncing chapters from Notion?"
  self.standalone = false
  self.visible = -> { view.index? || view.show? }

  def handle(query:, **)
    return error("Please select exactly one book.") unless query.one?

    book = query.first
    SyncBookChaptersFromNotionJob.perform_later(book.id)
    succeed "Queued Notion sync for #{book.title}."
  end
end
