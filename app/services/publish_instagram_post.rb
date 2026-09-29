# frozen_string_literal: true

# Publishes slides ({ url:, video: }) as a feed post, carousel, stories, or reel.
class PublishInstagramPost
  Error = Class.new(StandardError)

  API_VERSION = "v25.0"
  GRAPH_BASE = "https://graph.instagram.com/#{API_VERSION}"
  POLL_ATTEMPTS = 30
  POLL_SLEEP = 2

  def self.call(...)
    new(...).call
  end

  def initialize(user:, format:, slides:, caption: nil)
    @user = user
    @format = format.to_s
    @slides = slides
    @caption = caption.presence
  end

  # Returns the published media ids.
  def call
    raise Error, "Connect Instagram first." unless @user.instagram_authorized?
    raise Error, "Nothing to publish." if @slides.empty?
    raise Error, "Instagram must fetch media from a public URL (not localhost). Use production or a tunnel." if @slides.any? { private_media_host?(it[:url]) }

    case @format
    when "story"
      @slides.map { publish!(container!(**media_params(it), media_type: "STORIES")) }
    when "reel"
      raise Error, "A reel needs one video." unless @slides.one? && @slides.first[:video]
      [ publish!(container!(media_type: "REELS", video_url: @slides.first[:url], caption: @caption)) ]
    when "post"
      if @slides.one?
        slide = @slides.first
        params = slide[:video] ? { media_type: "REELS", video_url: slide[:url] } : { image_url: slide[:url] }
        [ publish!(container!(**params, caption: @caption)) ]
      else
        children = @slides.map { container!(**media_params(it, video_type: "VIDEO"), is_carousel_item: true) }
        [ publish!(container!(media_type: "CAROUSEL", children: children.join(","), caption: @caption)) ]
      end
    else
      raise Error, "Unknown format #{@format}."
    end
  end

  private

    def media_params(slide, video_type: nil)
      slide[:video] ? { media_type: video_type, video_url: slide[:url] } : { image_url: slide[:url] }
    end

    def private_media_host?(url)
      host = URI.parse(url.to_s).host.to_s.downcase
      host.blank? || host == "localhost" || host.end_with?(".local") || host == "127.0.0.1" || host == "::1"
    rescue URI::InvalidURIError
      true
    end

    def container!(**params)
      id = request!(:post, "#{@user.instagram_user_id}/media", params.merge(access_token: @user.instagram_access_token).compact)["id"]
      raise Error, "Instagram did not return a container id." if id.blank?

      wait_until_ready!(id)
      id
    end

    def wait_until_ready!(container_id)
      POLL_ATTEMPTS.times do
        status = request!(:get, container_id, fields: "status_code", access_token: @user.instagram_access_token)["status_code"]
        return if status.blank? || status == "FINISHED"
        raise Error, "Instagram media processing failed (#{status})." if status.in?(%w[ERROR EXPIRED])

        sleep POLL_SLEEP
      end

      raise Error, "Instagram media is still processing. Try again in a minute."
    end

    def publish!(container_id)
      request!(:post, "#{@user.instagram_user_id}/media_publish", creation_id: container_id, access_token: @user.instagram_access_token)["id"]
    end

    def connection
      @connection ||= Faraday.new(url: GRAPH_BASE) do |f|
        f.request :url_encoded
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def request!(method, path, params = {})
      response = connection.public_send(method, path) do |req|
        if method == :get
          req.params.update(params)
        else
          req.body = params
        end
      end

      body = response.body.is_a?(Hash) ? response.body : {}

      if !response.success? || body["error"]
        err = body["error"].is_a?(Hash) ? body["error"] : {}
        message = err["error_user_msg"].presence || err["error_user_title"].presence ||
          err["message"].presence || "Instagram API error (#{response.status})"
        raise Error, message
      end

      body
    end
end
