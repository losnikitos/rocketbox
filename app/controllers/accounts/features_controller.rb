# frozen_string_literal: true

module Accounts
  class FeaturesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_feature, except: :index

    def index
      @features = Feature::ALL.map { [ it, it.setting_for(Current.account) ] }
    end

    def update
      if @setting.update(setting_params)
        redirect_to features_path, notice: "#{@feature.name} saved."
      else
        redirect_to features_path, alert: @setting.errors.full_messages.to_sentence
      end
    end

    def generate
      return redirect_to(features_path, alert: "Turn #{@feature.name} on first.") unless @setting.enabled?

      post = @feature.create_post!(Current.account)
      redirect_to instagram_post_path(post), notice: "Generating #{@feature.name}…"
    rescue ActiveRecord::RecordNotFound => e
      redirect_to features_path, alert: e.message
    end

    private

      def set_feature
        @feature = Feature.find(params[:id])
        @setting = @feature.setting_for(Current.account)
      end

      def setting_params = params.expect(feature_setting: %i[enabled recipe_id layer_slug])
  end
end
