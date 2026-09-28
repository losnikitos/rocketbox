# frozen_string_literal: true

class SignupsController < ApplicationController
  layout "auth"
  skip_before_action :authenticate

  def show
    @whatsapp_url = "https://wa.me/#{WhatsappCloud.display_phone}?text=START"
  end
end
