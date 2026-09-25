# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def uploads
      @library_media = Current.user.library_media.with_attached_file.order(created_at: :desc)
    end
  end
end
