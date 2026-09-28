# frozen_string_literal: true

require "net/http"
require "stringio"
require "uri"

module WhatsappCloud
  Error = Class.new(StandardError)

  API_VERSION = "v21.0"
  GRAPH_BASE = "https://graph.facebook.com/#{API_VERSION}"
  PHONES = { "Test" => "15551712639", "Prod" => "447451273884" }.freeze
  PHONE_NUMBER_IDS = { "Test" => "1238456642695224", "Prod" => "1237261782813765" }.freeze

  module_function

  def access_token
    Rails.application.credentials.dig(:whatsapp, :access_token).presence ||
      raise("credentials.whatsapp.access_token is missing")
  end

  def display_phone
    PHONES[Rails.env.production? ? "Prod" : "Test"]
  end

  def phone_number_id
    PHONE_NUMBER_IDS[Rails.env.production? ? "Prod" : "Test"]
  end

  def app_secret
    Rails.application.credentials.dig(:whatsapp, :app_secret).presence
  end

  def webhook_verify_token
    Rails.application.credentials.dig(:whatsapp, :webhook_verify_token).presence
  end

  def get_media(media_id)
    request!(:get, media_id)
  end

  def download_media(media_id)
    meta = get_media(media_id)
    url = meta["url"].presence || raise(Error, "WhatsApp media #{media_id} has no url")
    mime_type = meta["mime_type"].presence || "application/octet-stream"

    # Net::HTTP keeps query param order. Faraday rebuilds the query string and
    # Meta's lookaside signature then returns 401.
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{access_token}"
      http.request(req)
    end
    raise Error, "WhatsApp media download failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    io = StringIO.new(response.body)
    io.define_singleton_method(:content_type) { mime_type }
    [ io, mime_type, meta ]
  end

  def send_text(phone_number_id:, to:, body:)
    send_message!(phone_number_id, to, "text", { preview_url: false, body: body })
  end

  def send_image(phone_number_id:, to:, link:, caption:)
    send_message!(phone_number_id, to, "image", { link: link, caption: caption })
  end

  # buttons: { "reply_id" => "Title" }; Meta allows up to 3, titles up to 20 chars.
  def send_buttons(phone_number_id:, to:, body:, buttons:)
    send_message!(phone_number_id, to, "interactive", {
      type: "button",
      body: { text: body },
      action: { buttons: buttons.map { |id, title| { type: "reply", reply: { id:, title: } } } }
    })
  end

  # Meta limits: body up to 1024 chars, display_text up to 20.
  def send_cta_url(phone_number_id:, to:, body:, display_text:, url:)
    send_message!(phone_number_id, to, "interactive", {
      type: "cta_url",
      body: { text: body },
      action: { name: "cta_url", parameters: { display_text:, url: } }
    })
  end

  def react(phone_number_id:, to:, message_id:, emoji: "👍")
    send_message!(phone_number_id, to, "reaction", { message_id: message_id, emoji: emoji })
  end

  def send_message!(phone_number_id, to, type, content)
    params = { messaging_product: "whatsapp", recipient_type: "individual", to: to, type: type, type.to_sym => content }
    log = { channel: "whatsapp", recipient: to, kind: type, payload: params, user: User.find_by(whatsapp_phone: to),
            body: content[:body].is_a?(Hash) ? content[:body][:text] : content[:body] || content[:caption] || content[:emoji] }
    response = request!(:post, "#{phone_number_id}/messages", params)
    OutgoingMessage.log(**log, external_id: response.dig("messages", 0, "id"))
    response
  rescue => e
    OutgoingMessage.log(**log, error: "#{e.class}: #{e.message}") if log
    raise
  end

  def valid_signature?(raw_body, signature_header)
    secret = app_secret
    return true if secret.blank?
    return false if signature_header.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
  end

  def reset!
    @connection = nil
  end

  def connection
    @connection ||= Faraday.new(url: GRAPH_BASE) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def request!(method, path, params = {})
    response = connection.public_send(method, path) do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      if method == :get
        req.params.update(params)
      else
        req.body = params
      end
    end

    body = response.body.is_a?(Hash) ? response.body : {}
    if !response.success? || body["error"]
      err = body["error"].is_a?(Hash) ? body["error"] : {}
      message = err["message"].presence || "WhatsApp API error (#{response.status})"
      raise Error, message
    end

    body
  end
end
