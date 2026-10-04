# frozen_string_literal: true

module Accounts
  class CalendarController < ApplicationController
    layout "app"

    def show
      refresh if params[:fetch]
      @calendar = Current.account.fresha_calendar
    end

    private

      def refresh
        Current.account.update!(fresha_calendar: FreshaAvailability.fetch.as_json)
      rescue FreshaAvailability::Error, Faraday::Error => e
        flash.now[:alert] = "Fresha: #{e.message}"
      end
  end
end
