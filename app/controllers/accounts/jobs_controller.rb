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

    # The checked jobs become the oldest of them, holding all their media.
    def merge
      jobs = Current.account.jobs.where(id: Array(params[:job_ids])).to_a
      return redirect_to(jobs_path, alert: "Select at least two jobs to merge.") if jobs.size < 2

      job = Job.merge!(jobs)
      redirect_to jobs_path, notice: "Merged into @#{job.slug}."
    end
  end
end
