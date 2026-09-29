# frozen_string_literal: true

# xAI Grok Imagine: image edits and image-to-video.
module Xai
  Error = Class.new(StandardError)
  TransientError = Class.new(Error)

  API_BASE = "https://api.x.ai/v1"
  IMAGE_MODEL = "grok-imagine-image-2.0"
  VIDEO_MODEL = "grok-imagine-video-1.5"
  VIDEO_DURATION = 8
  VIDEO_RESOLUTION = "720p"
  POLL_ATTEMPTS = 90
  POLL_SLEEP = 2
  NETWORK_ERRORS = [ Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError ].freeze

  extend self

  # Returns the edited image bytes (JPEG).
  def edit_image(prompt:, blob:)
    body = request!(:post, "images/edits", model: IMAGE_MODEL, prompt:, image: { url: data_uri(blob), type: "image_url" }, response_format: "b64_json")
    Base64.decode64(body.dig("data", 0, "b64_json").presence || raise(Error, "xAI did not return an image."))
  end

  # Returns MP4 bytes animated from one image or referencing several.
  def generate_video(prompt:, blobs:, aspect_ratio: "9:16")
    params = { model: VIDEO_MODEL, prompt:, duration: VIDEO_DURATION, aspect_ratio:, resolution: VIDEO_RESOLUTION }
    if blobs.one?
      params[:image] = { url: data_uri(blobs.first), type: "image_url" }
    else
      params[:reference_images] = blobs.map { { url: data_uri(it) } }
    end

    request_id = request!(:post, "videos/generations", params)["request_id"].presence || raise(Error, "xAI did not return a request id.")
    download!(poll_video!(request_id))
  end

  private

    def poll_video!(request_id)
      POLL_ATTEMPTS.times do
        payload = request!(:get, "videos/#{request_id}")
        status = payload["status"].to_s
        return payload.dig("video", "url") if status == "done" && payload.dig("video", "url").present?
        raise Error, error_message(payload).presence || "Video generation failed (#{status})." if status.in?(%w[failed expired])

        sleep POLL_SLEEP
      end

      raise TransientError, "Video generation is still processing. Try again shortly."
    end

    def download!(url)
      response = Faraday.get(url) do |req|
        req.options.open_timeout = 30
        req.options.timeout = 300
      end
      raise TransientError, "Could not download generated video (#{response.status})." unless response.success?
      raise Error, "Generated video was empty." if response.body.blank?

      response.body
    rescue *NETWORK_ERRORS => e
      raise TransientError, "Could not download generated video: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "Could not download generated video: #{e.message}"
    end

    def request!(method, path, params = nil)
      response = connection.public_send(method, path) do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        if params
          req.headers["Content-Type"] = "application/json"
          req.body = params.to_json
        end
      end
      body = response.body.is_a?(Hash) ? response.body : {}
      raise Error, error_message(body).presence || "xAI API error (#{response.status})" unless response.success?

      body
    rescue *NETWORK_ERRORS => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def error_message(payload)
      payload.dig("error", "message").presence || (payload["error"].presence if payload["error"].is_a?(String))
    end

    def data_uri(blob)
      "data:#{blob.content_type.presence || "image/jpeg"};base64,#{Base64.strict_encode64(blob.download)}"
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
