# frozen_string_literal: true

class DocumentsController < ApplicationController
  def show
    @document = Document.published.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "That page could not be found."
  end
end
