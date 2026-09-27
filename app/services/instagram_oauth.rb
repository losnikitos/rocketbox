# frozen_string_literal: true

# Instagram API with Instagram Login (business accounts).
class InstagramOauth
  Error = Class.new(StandardError)

  SCOPES = %w[instagram_business_basic instagram_business_content_publish].freeze

  def self.authorize_url(redirect_uri:, state:)
    "https://www.instagram.com/oauth/authorize?" + {
      client_id: app_id, redirect_uri:, response_type: "code", scope: SCOPES.join(","), state:
    }.to_query
  end

  # Returns [instagram_user_id, long_lived_access_token].
  # ponytail: long-lived tokens expire after 60 days and we don't refresh them; owner re-authorizes.
  # Upgrade: store expires_in and run a job hitting graph.instagram.com/refresh_access_token.
  def self.exchange(code:, redirect_uri:)
    short = request(:post, "https://api.instagram.com/oauth/access_token",
      client_id: app_id, client_secret: app_secret, grant_type: "authorization_code", redirect_uri:, code:)
    short = short["data"]&.first || short

    token = request(:get, "https://graph.instagram.com/access_token",
      grant_type: "ig_exchange_token", client_secret: app_secret, access_token: short.fetch("access_token")).fetch("access_token")
    user_id = request(:get, "#{PublishInstagramReel::GRAPH_BASE}/me", fields: "user_id", access_token: token).fetch("user_id")

    [ user_id.to_s, token ]
  rescue KeyError => e
    raise Error, "Instagram did not return #{e.key}."
  end

  def self.request(method, url, params)
    response = Faraday.new { |f| f.request :url_encoded; f.response :json }.public_send(method, url, params)
    body = response.body.is_a?(Hash) ? response.body : {}
    return body if response.success? && !body["error"]

    error = body["error"].is_a?(Hash) ? body["error"]["message"] : nil
    raise Error, error.presence || body["error_message"].presence || "Instagram authorization failed (#{response.status})."
  end

  def self.app_id
    Rails.application.credentials.dig(:instagram, :app_id).presence || raise(Error, "credentials.instagram.app_id is missing")
  end

  def self.app_secret
    Rails.application.credentials.dig(:instagram, :app_secret).presence || raise(Error, "credentials.instagram.app_secret is missing")
  end
end
