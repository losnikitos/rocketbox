# frozen_string_literal: true

class GenerateSmmPostVideo
  Error = Class.new(StandardError)
  TransientError = Class.new(Error)

  API_BASE = "https://api.x.ai/v1"
  MODEL = "grok-imagine-video-1.5"
  ASPECT_RATIO = "9:16"
  DURATION = 8
  RESOLUTION = "720p"
  POLL_ATTEMPTS = 90
  POLL_SLEEP = 2

  def self.call(smm_post:)
    new(smm_post:).call
  end

  def initialize(smm_post:)
    @smm_post = smm_post
  end

  def call
    raise Error, "Prompt is missing." if @smm_post.prompt.blank?
    raise Error, "Select at least one image." if source_images.empty?

    @smm_post.mark_generating!
    request_id = start_generation!
    @smm_post.update!(generation_request_id: request_id)
    video_url = poll_until_ready!(request_id)
    attach_video!(video_url)
    @smm_post.mark_ready!
    @smm_post
  rescue TransientError
    raise
  rescue Error => e
    @smm_post.mark_failed!(e.message)
    raise
  end

  private

    def source_images
      @source_images ||= @smm_post.library_media.includes(file_attachment: :blob).select(&:story_image?)
    end

    def start_generation!
      body = {
        model: MODEL,
        prompt: @smm_post.prompt.body,
        duration: DURATION,
        aspect_ratio: ASPECT_RATIO,
        resolution: RESOLUTION
      }

      if source_images.one?
        body[:image] = { url: data_uri(source_images.first), type: "image_url" }
      else
        body[:reference_images] = source_images.map { |media| { url: data_uri(media) } }
      end

      response = connection.post("videos/generations") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = body.to_json
      end

      payload = response_body(response)
      unless response.success?
        raise Error, error_message(payload, response.status)
      end

      payload["request_id"].presence || raise(Error, "xAI did not return a request id.")
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def poll_until_ready!(request_id)
      POLL_ATTEMPTS.times do
        response = connection.get("videos/#{request_id}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
        end
        payload = response_body(response)

        unless response.success?
          raise Error, error_message(payload, response.status)
        end

        status = payload["status"].to_s
        return payload.dig("video", "url") if status == "done" && payload.dig("video", "url").present?
        raise Error, error_message(payload, response.status).presence || "Video generation failed (#{status})." if status.in?(%w[failed expired])

        sleep POLL_SLEEP
      end

      raise TransientError, "Video generation is still processing. Try again shortly."
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "xAI request failed: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "xAI request failed: #{e.message}"
    end

    def attach_video!(video_url)
      bytes = download_video!(video_url)
      @smm_post.generated_video.attach(
        io: StringIO.new(bytes),
        filename: "smm-post-#{@smm_post.id}.mp4",
        content_type: "video/mp4"
      )
    end

    def download_video!(video_url)
      response = Faraday.get(video_url) do |req|
        req.options.open_timeout = 30
        req.options.timeout = 300
      end
      raise TransientError, "Could not download generated video (#{response.status})." unless response.success?
      raise Error, "Generated video was empty." if response.body.blank?

      response.body
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise TransientError, "Could not download generated video: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "Could not download generated video: #{e.message}"
    end

    def data_uri(media)
      raise Error, "Media file is missing." unless media.file.attached?

      content_type = media.file.content_type.presence || "image/jpeg"
      encoded = Base64.strict_encode64(media.file.download)
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

    def response_body(response)
      response.body.is_a?(Hash) ? response.body : {}
    end

    def error_message(payload, status)
      payload.dig("error", "message").presence ||
        payload["error"].presence ||
        "xAI API error (#{status})"
    end
end
