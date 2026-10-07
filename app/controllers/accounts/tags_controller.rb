# frozen_string_literal: true

module Accounts
  # Creates a tag from the tag dropdown's search (see shared/_tag_pick); an existing tag of that name is returned as is.
  class TagsController < ApplicationController
    before_action :authenticate_admin!

    def create
      tag = Tag.find_or_create_by(name: params.expect(:name))
      if tag.persisted?
        render json: tag.slice(:id, :name)
      else
        render json: { error: tag.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end
    end
  end
end
