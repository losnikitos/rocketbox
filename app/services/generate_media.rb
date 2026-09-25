# frozen_string_literal: true

class GenerateMedia
  Error = Class.new(StandardError)
  TransientError = Class.new(Error)

  API_BASE = "https://api.x.ai/v1"
  # ponytail: busy-poll with fixed attempt ceiling; upgrade to webhook/callback if xAI adds one.
  VIDEO_POLL_ATTEMPTS = 60
  VIDEO_POLL_INTERVAL = 5

  def self.call(generation:)
    new(generation:).call
  end

  def initialize(generation:)
    @generation = generation
  end

  def call
    if @generation.image?
      attach_image!(generate_image!)
    elsif @generation.video?
      attach_video!(generate_video!)
    else
      raise Error, "Unsupported media type: #{@generation.media_type}"
    end

    @generation.update!(status: :succeeded, error_message: nil)
    @generation
  rescue TransientError
    raise
  rescue Error => e
    @generation.update!(status: :failed, error_message: e.message)
    raise
  rescue StandardError => e
    @generation.update!(status: :failed, error_message: e.message)
    raise Error, e.message
  end

  private

    def generate_image!
      response = connection.post("images/generations") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: @generation.model,
          prompt: @generation.prompt,
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

    def attach_image!(b64)
      bytes = Base64.decode64(b64)
      @generation.file.attach(
        io: StringIO.new(bytes),
        filename: "generation-#{@generation.id}.jpg",
        content_type: "image/jpeg"
      )
    end

    def generate_video!
      request_id = start_video!
      poll_video!(request_id)
    end

    def start_video!
      response = connection.post("videos/generations") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: @generation.model,
          prompt: @generation.prompt
        }.to_json
      end

      body = response.body.is_a?(Hash) ? response.body : {}
      unless response.success?
        message = body.dig("error", "message").presence || "xAI API error (#{response.status})"
        raise Error, message
      end

      body["request_id"].presence || raise(Error, "xAI did not return a request_id.")
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def poll_video!(request_id)
      VIDEO_POLL_ATTEMPTS.times do
        response = connection.get("videos/#{request_id}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
        end

        body = response.body.is_a?(Hash) ? response.body : {}
        unless response.success?
          message = body.dig("error", "message").presence || "xAI API error (#{response.status})"
          raise Error, message
        end

        case body["status"]
        when "done"
          url = body.dig("video", "url").presence || raise(Error, "xAI did not return a video URL.")
          return download_bytes!(url)
        when "failed", "expired"
          message = body.dig("error", "message").presence || "Video generation #{body['status']}"
          raise Error, message
        else
          sleep VIDEO_POLL_INTERVAL
        end
      end

      raise Error, "Video generation timed out after #{VIDEO_POLL_ATTEMPTS * VIDEO_POLL_INTERVAL}s"
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def download_bytes!(url)
      response = Faraday.get(url)
      raise Error, "Failed to download video (#{response.status})" unless response.success?

      response.body
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "Video download failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "Video download failed: #{e.message}"
    end

    def attach_video!(bytes)
      @generation.file.attach(
        io: StringIO.new(bytes),
        filename: "generation-#{@generation.id}.mp4",
        content_type: "video/mp4"
      )
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
