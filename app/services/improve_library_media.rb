# frozen_string_literal: true

class ImproveLibraryMedia
  Error = Class.new(StandardError)
  TransientError = Class.new(Error)

  API_BASE = "https://api.x.ai/v1"
  MODEL = "grok-imagine-image-2.0"
  PROMPT = "Make this look like professional content for social media advertising."

  def self.call(media:)
    new(media:).call
  end

  def initialize(media:)
    @media = media
  end

  def call
    raise Error, "Only images can be improved with AI." unless @media.story_image?
    raise Error, "Media file is missing." unless @media.file.attached?

    b64 = edit_image!
    store!(b64)
  end

  private

    def edit_image!
      response = connection.post("images/edits") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: MODEL,
          prompt: PROMPT,
          image: { url: data_uri, type: "image_url" },
          response_format: "b64_json"
        }.to_json
      end

      body = response.body.is_a?(Hash) ? response.body : {}
      unless response.success?
        message = body.dig("error", "message").presence || "xAI API error (#{response.status})"
        raise Error, message
      end

      body.dig("data", 0, "b64_json").presence || raise(Error, "xAI did not return an image.")
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def store!(b64)
      uid = "ai-#{SecureRandom.uuid}"
      bytes = Base64.decode64(b64)
      created = LibraryMedia.create!(
        telegram_file_id: uid,
        telegram_file_unique_id: uid,
        kind: "photo",
        user: @media.user
      )
      created.file.attach(
        io: StringIO.new(bytes),
        filename: "improved-#{@media.id}.jpg",
        content_type: "image/jpeg"
      )
      created
    end

    def data_uri
      content_type = @media.file.content_type.presence || "image/jpeg"
      encoded = Base64.strict_encode64(@media.file.download)
      "data:#{content_type};base64,#{encoded}"
    end

    def api_key
      Rails.application.credentials.dig(:xai, :api_key).presence || raise(Error, "xAI API key is not configured.")
    end

    def connection
      @connection ||= Faraday.new(url: API_BASE) do |f|
        f.options.open_timeout = 30
        f.options.timeout = 300
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
end
