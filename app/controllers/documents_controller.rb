# frozen_string_literal: true

class DocumentsController < ApplicationController
  skip_before_action :authenticate, only: :show

  def show
    @document = Document.published.friendly.find(params[:slug])
    @main_container_class = "max-w-3xl"
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "That page could not be found."
  end
end
