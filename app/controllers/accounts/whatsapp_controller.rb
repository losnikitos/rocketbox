# frozen_string_literal: true

module Accounts
  class WhatsappController < ApplicationController
    layout "app"

    def show
      @messages, @reactions = Current.account.whatsapp_thread(admin: Current.user&.admin?)
      return if Current.account.whatsapp_phone

      Current.account.regenerate_whatsapp_link_code unless Current.account.whatsapp_link_code
      @whatsapp_url = "https://wa.me/#{WhatsappCloud.display_phone}?text=START_#{Current.account.whatsapp_link_code}"
    end

    def create
      phone = Current.account.whatsapp_phone
      return redirect_to(whatsapp_path, alert: "Connect WhatsApp first.") if phone.blank?

      body = params[:body].to_s.strip
      files = dashboard_files
      return head :no_content if body.blank? && files.empty?

      # Broadcast before the reply is enqueued, so the first paint is the new message alone.
      payload = if files.any?
        store_media!(phone, body, files)
        nil
      else
        store_text!(phone, body)
      end
      Current.account.broadcast_whatsapp_thread
      ReplyWhatsappMessageJob.perform_later(payload) if payload
      head :no_content
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
        {
          "entry" => [ {
            "changes" => [ {
              "field" => "messages",
              "value" => {
                "metadata" => { "phone_number_id" => WhatsappCloud.phone_number_id },
                "messages" => [ message ]
              }
            } ]
          } ]
        }
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
  end
end
