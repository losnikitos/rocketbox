# frozen_string_literal: true

module Accounts
  class JobsController < ApplicationController
    layout "app"

    def index
      @jobs = Current.account.jobs.ordered.includes(library_media: [ :transformation_run, { file_attachment: :blob } ])
    end

    # A new job for one media, from its page's job dropdown.
    def create
      media = Current.account.library_media.find(params.expect(:library_media_id))
      job = Current.account.jobs.create!
      media.update!(job:)
      redirect_to helpers.library_item_path(media), notice: "Added to @#{job.slug}."
    end
  end
end
