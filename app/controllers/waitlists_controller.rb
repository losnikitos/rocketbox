# frozen_string_literal: true

class WaitlistsController < ApplicationController
  def new
    @entry = WaitlistEntry.new
  end

  def create
    @entry = WaitlistEntry.new(waitlist_params)

    if @entry.save
      redirect_to try_thanks_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def thanks
  end

  private

    def waitlist_params
      params.expect(waitlist_entry: [ :business_link, :email, :phone ])
    end
end
