# frozen_string_literal: true

module Accounts
  class ReviewsController < ApplicationController
    layout "app"

    def index
      scope = params[:archived] ? Current.account.reviews.archived : Current.account.reviews.active
      @reviews = scope.with_attached_avatar.with_attached_media.order(created_at: :desc)
    end

    def update
      review = Current.account.reviews.find(params[:id])
      review.update!(archived_at: review.archived? ? nil : Time.current)
      redirect_to reviews_path(archived: (1 unless review.archived?)),
        notice: review.archived? ? "Review archived." : "Review restored."
    end

    def destroy
      unless Current.user.admin?
        redirect_to reviews_path, alert: "You are not allowed to delete reviews."
        return
      end

      Current.account.reviews.find(params[:id]).destroy!
      redirect_to reviews_path, notice: "Review deleted."
    end
  end
end
