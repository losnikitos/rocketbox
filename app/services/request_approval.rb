# frozen_string_literal: true

# Asks the media owner on WhatsApp to approve or reject a waiting Approval step run.
# Skips quietly when they have no WhatsApp number (in-app approve still works).
class RequestApproval
  URL_OPTIONS = WhatsappOnboarding::URL_OPTIONS

  def self.call(run) = new(run).call

  def initialize(run)
    @run = run
  end

  def call
    user = @run.result&.user
    to = user&.whatsapp_phone.presence or return
    media = @run.source_media.first
    return unless media&.file&.attached?

    ActiveStorage::Current.url_options ||= URL_OPTIONS
    header = if media.video?
      id = WhatsappCloud.upload_media(WhatsappCloud.phone_number_id, StringIO.new(media.file.download),
        filename: media.file.filename.to_s, content_type: media.file.content_type)
      { type: "video", id: }
    else
      { type: "image", link: media.file.url(expires_in: 1.hour) }
    end
    label = @run.transformation.options["button"].to_s.truncate(20, omission: "").presence
    buttons = if label
      { "approval:approve:#{@run.id}" => label }
    else
      {
        "approval:approve:#{@run.id}" => "Approve",
        "approval:reject:#{@run.id}" => "Reject"
      }
    end
    WhatsappCloud.send_buttons(
      phone_number_id: WhatsappCloud.phone_number_id,
      to:,
      body: @run.transformation.body.presence || "Approve this for posting?",
      buttons:,
      header:
    )
  rescue StandardError => e
    Rails.logger.warn("[RequestApproval] run=#{@run.id} #{e.class}: #{e.message}")
  end
end
