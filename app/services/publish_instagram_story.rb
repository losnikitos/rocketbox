# frozen_string_literal: true

class PublishInstagramStory
  Error = Class.new(StandardError)

  API_VERSION = "v25.0"
  # Instagram Login tokens (IG…) use graph.instagram.com; Facebook Login (EA…) uses graph.facebook.com.
  GRAPH_BASE = "https://graph.instagram.com/#{API_VERSION}"
  # Meta suggests ~1/min poll for video; waits run inside PublishInstagramStoryJob.
  POLL_ATTEMPTS = 30
  POLL_SLEEP = 2

  def self.call(user:, media:, media_url:)
    new(user:, media:, media_url:).call
  end

  def initialize(user:, media:, media_url:)
    @user = user
    @media = media
    @media_url = media_url
  end

  def call
    raise Error, "Connect Instagram under Integrations first." if credentials_blank?
    raise Error, "Only photos and videos can be published as stories." unless @media.story_publishable?
    raise Error, "Instagram must fetch the image from a public URL (not localhost). Use production or a tunnel." if private_media_host?

    container_id = create_container!
    wait_until_ready!(container_id)
    publish!(container_id)
  end

  private

    def credentials_blank?
      @user.instagram_user_id.blank? || @user.instagram_access_token.blank?
    end

    # Meta downloads image_url/video_url itself; private hosts always fail with a misleading media_type error.
    def private_media_host?
      host = URI.parse(@media_url).host.to_s.downcase
      host.blank? || host == "localhost" || host.end_with?(".local") || host == "127.0.0.1" || host == "::1"
    rescue URI::InvalidURIError
      true
    end

    def create_container!
      params = { media_type: "STORIES", access_token: @user.instagram_access_token }
      if @media.story_image?
        params[:image_url] = @media_url
      else
        params[:video_url] = @media_url
      end

      request!(:post, "#{@user.instagram_user_id}/media", params).fetch("id")
    rescue KeyError
      raise Error, "Instagram did not return a container id."
    end

    def wait_until_ready!(container_id)
      POLL_ATTEMPTS.times do
        status = request!(:get, container_id, fields: "status_code", access_token: @user.instagram_access_token)["status_code"]
        return if status.blank? || status == "FINISHED"
        raise Error, "Instagram story processing failed (#{status})." if status.in?(%w[ERROR EXPIRED])

        sleep POLL_SLEEP
      end

      raise Error, "Instagram story is still processing. Try again in a minute."
    end

    def publish!(container_id)
      request!(
        :post,
        "#{@user.instagram_user_id}/media_publish",
        creation_id: container_id,
        access_token: @user.instagram_access_token
      )
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
