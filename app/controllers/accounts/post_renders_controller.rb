# frozen_string_literal: true

module Accounts
  class PostRendersController < ApplicationController
    before_action :authenticate_admin!

    def show
      render_row = PostRender.find(params[:id])
      return head :not_found unless render_row.done? && render_row.file.attached?

      redirect_to rails_blob_path(render_row.file, disposition: "attachment")
    end
  end
end
