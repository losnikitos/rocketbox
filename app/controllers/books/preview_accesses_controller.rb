# frozen_string_literal: true

module Books
  class PreviewAccessesController < ApplicationController
    skip_before_action :authenticate

    def show
      email = DemoPreviewLink.read(params[:t])

      unless email
        redirect_to new_free_preview_path, alert: "That link is invalid or has expired. Request a new preview below."
        return
      end

      redirect_to books_coffeeshop_chapter_path(1)
    end
  end
end
