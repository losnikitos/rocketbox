# frozen_string_literal: true

module Accounts
  class ServicesController < ApplicationController
    layout "app"

    before_action :set_service, only: %i[edit update destroy]

    def index
      @services = Current.account.services.order(:created_at)
    end

    def new
      @service = Current.account.services.new
    end

    def create
      @service = Current.account.services.new(service_params)
      if @service.save
        redirect_to services_path, notice: "Service added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @service.update(service_params)
        redirect_to services_path, notice: "Service saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @service.destroy!
      redirect_to services_path, notice: "Service removed."
    end

    private

      def set_service
        @service = Current.account.services.find(params[:id])
      end

      def service_params
        params.expect(service: %i[name price duration description])
      end
  end
end
