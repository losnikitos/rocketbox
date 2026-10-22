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

    def create
      phone = Current.account.whatsapp_phone
      return redirect_to(whatsapp_path, alert: "Connect WhatsApp first.") if phone.blank?

      body = params[:body].to_s.strip
      files = dashboard_files
      return redirect_to(whatsapp_path) if body.blank? && files.empty?

      files.any? ? store_media!(phone, body, files) : store_text!(phone, body)
      redirect_to whatsapp_path
    end

    def destroy
      Current.account.update!(OnboardingController::RESETS["whatsapp"])
      redirect_to whatsapp_path, notice: "WhatsApp disconnected."
    end

    private
      def dashboard_files
        Array(params[:attachments]).filter_map do |file|
          next unless file.respond_to?(:tempfile)

          file = LibraryMedia.heic_as_jpeg(file) if file.original_filename.to_s.match?(/\.hei[cf]\z/i)
          file
        end
      end

      def store_text!(phone, body)
        message = { "from" => phone, "id" => "dash.#{SecureRandom.hex(8)}", "type" => "text", "text" => { "body" => body } }
        StoreIncomingMessage.whatsapp(message)
        ReplyWhatsappMessage.call(
          "entry" => [ {
            "changes" => [ {
              "field" => "messages",
              "value" => {
                "metadata" => { "phone_number_id" => WhatsappCloud.phone_number_id },
                "messages" => [ message ]
              }
            } ]
          } ]
        )
      rescue WhatsappCloud::Error => error
        flash[:alert] = error.message
      end

      # One bubble, caption on the media. Each file is also Inbox media, which autoruns on attach.
      def store_media!(phone, body, files)
        type = whatsapp_type(files.first)
        message = {
          "from" => phone,
          "id" => "dash.#{SecureRandom.hex(8)}",
          "type" => type,
          type => (body.present? ? { "caption" => body } : {})
        }
        incoming = StoreIncomingMessage.whatsapp(message)
        files.each do |file|
          media = Current.account.library_media.create!(
            kind: LibraryMedia.kind_for(file.content_type),
            folder: Folder.inbox,
            whatsapp_from: phone
          )
          media.file.attach(file)
          incoming&.attachments&.attach(media.file.blob)
        end
      end

      def whatsapp_type(file)
        { "photo" => "image", "video" => "video", "audio" => "audio" }.fetch(LibraryMedia.kind_for(file.content_type), "document")
      end

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
        if Current.user&.admin?
          bubbles += WorkflowRun.played_by(account)
            .includes(:workflow, step_runs: { inputs: { item: :folder }, result: :folder }).to_a
          rank = { IncomingMessage => 0, WorkflowRun => 1, OutgoingMessage => 2 }
          bubbles.sort_by! { |record| [ record.created_at, rank.fetch(record.class), record.id ] }
        else
          bubbles.sort_by!(&:created_at)
        end
        [ bubbles, grouped ]
      end
  end
end
