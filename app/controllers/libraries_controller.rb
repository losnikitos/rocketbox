# frozen_string_literal: true

class LibrariesController < ApplicationController
  def show
    @telegram_uploads = Current.user.telegram_uploads.with_attached_file.order(created_at: :desc)
  end
end
