# frozen_string_literal: true

module Accounts
  class TranscriptController < ApplicationController
    layout "app"
    before_action :authenticate_admin!

    def show
      @system_messages = RocketboxAgent.system_messages(Current.account)
      @transcript = AgentTranscript.preview(Current.account)
    end
  end
end
