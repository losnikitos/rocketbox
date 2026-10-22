# frozen_string_literal: true

module WhatsappHelper
  MEDIA_LABELS = {
    "image" => "Photo",
    "video" => "Video",
    "audio" => "Audio",
    "document" => "Document",
    "sticker" => "Sticker"
  }.freeze

  def whatsapp_bubble_text(message)
    return message.body if message.body.present?

    payload = whatsapp_payload(message)
    payload.dig("interactive", "button_reply", "title").presence ||
      payload.dig("button", "text").presence
  end

  def whatsapp_kind_label(message)
    return if whatsapp_bubble_text(message).present?
    return if message.is_a?(IncomingMessage) && message.attachments.attached?
    return if whatsapp_outgoing_media(message)

    MEDIA_LABELS[message.kind]
  end

  def whatsapp_buttons(message)
    interactive = whatsapp_payload(message)["interactive"]
    return [] unless interactive.is_a?(Hash)

    titles = Array(interactive.dig("action", "buttons")).filter_map { |button| button.dig("reply", "title").presence }
    cta = interactive.dig("action", "parameters", "display_text").presence
    titles << cta if cta
    titles
  end

  # [ "image"|"video", url ] for an outgoing media bubble, including button-message headers.
  def whatsapp_outgoing_media(message)
    return unless message.is_a?(OutgoingMessage)

    payload = whatsapp_payload(message)
    if (url = payload.dig("image", "link").presence || payload.dig("interactive", "header", "image", "link").presence)
      [ "image", url ]
    elsif (url = payload.dig("video", "link").presence || payload.dig("interactive", "header", "video", "link").presence)
      [ "video", url ]
    end
  end

  def whatsapp_reactions(message, reactions)
    return [] if message.external_id.blank?

    Array(reactions[message.external_id]).filter_map do |reaction|
      reaction.body.presence || whatsapp_payload(reaction).dig("reaction", "emoji").presence
    end
  end

  def whatsapp_day(time)
    date = time.to_date
    if date == Date.current then "Today"
    elsif date == Date.yesterday then "Yesterday"
    else l(date, format: :long)
    end
  end

  def whatsapp_payload(message)
    message.payload.is_a?(Hash) ? message.payload : {}
  end
end
