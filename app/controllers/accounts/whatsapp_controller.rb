# frozen_string_literal: true

module Accounts
  class WhatsappController < ApplicationController
    layout "app"

    def show
      @messages, @reactions = whatsapp_thread
      return if Current.account.whatsapp_phone

      Current.account.regenerate_whatsapp_link_code unless Current.account.whatsapp_link_code
      @whatsapp_url = "https://wa.me/#{WhatsappCloud.display_phone}?text=START_#{Current.account.whatsapp_link_code}"
    end

    def destroy
      Current.account.update!(OnboardingController::RESETS["whatsapp"])
      redirect_to whatsapp_path, notice: "WhatsApp disconnected."
    end

    private
      # The first inbound text is stored before the user exists, so match the phone too.
      def whatsapp_thread
        account = Current.account
        phone = account.whatsapp_phone
        incoming = IncomingMessage.where(channel: "whatsapp", user: account)
        outgoing = OutgoingMessage.where(channel: "whatsapp", user: account)
        if phone.present?
          incoming = incoming.or(IncomingMessage.where(channel: "whatsapp", sender: phone))
          outgoing = outgoing.or(OutgoingMessage.where(channel: "whatsapp", recipient: phone))
        end

        rows = incoming.with_attached_attachments.to_a + outgoing.to_a
        reactions, bubbles = rows.partition { |message| message.kind == "reaction" }
        grouped = reactions.group_by { |message| message.payload.is_a?(Hash) ? message.payload.dig("reaction", "message_id").presence : nil }
        grouped.delete(nil)
        [ bubbles.sort_by(&:created_at), grouped ]
      end
  end
end
