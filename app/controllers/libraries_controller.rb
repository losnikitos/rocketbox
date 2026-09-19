# frozen_string_literal: true

class LibrariesController < ApplicationController
  def show
    @library_media = Current.user.library_media.with_attached_file.order(created_at: :desc)
  end
end
