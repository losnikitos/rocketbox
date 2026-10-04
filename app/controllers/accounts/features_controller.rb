# frozen_string_literal: true

module Accounts
  class FeaturesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_feature, except: :index

    def index
      @features = Feature::ALL.map { [ it, it.setting_for(Current.account) ] }
    end

    def show
      @recipe = @feature.recipe(Current.account)
      @photos = @feature.ready_photos(Current.account).with_attached_file.order(created_at: :desc).select(&:story_image?)
      @reviews = @feature.five_star_reviews(Current.account).order(created_at: :desc) if @feature.reviews?
    end

    def update
      if @setting.update(setting_params)
        redirect_to feature_path(@feature), notice: "#{@feature.name} saved."
      else
        redirect_to feature_path(@feature), alert: @setting.errors.full_messages.to_sentence
      end
    end

    def generate
      photo = @feature.ready_photos(Current.account).find(params[:photo_id]) if params[:photo_id].present?
      review = @feature.five_star_reviews(Current.account).find(params[:review_id]) if @feature.reviews? && params[:review_id].present?
      post = @feature.create_post!(Current.account, photo:, review:)
      redirect_to instagram_post_path(post), notice: "Composing #{@feature.name}…"
    rescue ActiveRecord::RecordNotFound => e
      redirect_to feature_path(@feature), alert: e.message
    end

    private

      def set_feature
        @feature = Feature.find(params[:id])
        @setting = @feature.setting_for(Current.account)
      end

      def setting_params = params.expect(feature_setting: %i[enabled recipe_id layer_slug])
  end
end
