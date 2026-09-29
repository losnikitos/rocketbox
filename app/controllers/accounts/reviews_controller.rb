# frozen_string_literal: true

module Accounts
  class ReviewsController < ApplicationController
    layout "app"

    PER_PAGE = 20

    def index
      scope = if params[:archived]
        Current.account.reviews.archived
      elsif params[:photos]
        Current.account.reviews.active.with_media
      elsif params[:source].present?
        Current.account.reviews.active.where(source: params[:source])
      else
        Current.account.reviews.active
      end
      @pages = [ (scope.count / PER_PAGE.to_f).ceil, 1 ].max
      @page = params[:page].to_i.clamp(1, @pages)
      @reviews = scope.with_attached_avatar.with_attached_media.order(created_at: :desc)
        .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    def update
      review = Current.account.reviews.find(params[:id])
      review.update!(archived_at: review.archived? ? nil : Time.current)
      redirect_back_or_to reviews_path(archived: (1 unless review.archived?)),
        notice: review.archived? ? "Review archived." : "Review restored."
    end

    def destroy
      unless Current.user.admin?
        redirect_to reviews_path, alert: "You are not allowed to delete reviews."
        return
      end

      Current.account.reviews.find(params[:id]).destroy!
      redirect_back_or_to reviews_path, notice: "Review deleted."
    end
  end
end
