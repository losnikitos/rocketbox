# frozen_string_literal: true

# https://docs.firecrawl.dev/api-reference/endpoint/scrape
module Firecrawl
  Error = Class.new(StandardError)

  BASE_URL = "https://api.firecrawl.dev"

  module_function

  def api_key
    Rails.application.credentials.dig(:firecrawl, :api_key).presence || raise(Error, "credentials.firecrawl.api_key is missing")
  end

  # => { extracted: Hash, screenshot_url: String }
  def extract(url, data_instruction:, schema:)
    response = connection.post("/v2/scrape", {
      url: url,
      formats: [ { type: "json", prompt: data_instruction, schema: schema }, "screenshot" ]
    })
    body = response.body.is_a?(Hash) ? response.body : {}
    unless response.success? && body["success"]
      raise Error, body["error"].presence || "Firecrawl scrape failed (HTTP #{response.status})"
    end

    { extracted: body.dig("data", "json"), screenshot_url: body.dig("data", "screenshot") }
  end

  def connection
    Faraday.new(url: BASE_URL, headers: { "Authorization" => "Bearer #{api_key}" }, request: { timeout: 180 }) do |f|
      f.request :json
      f.response :json
    end
  end
end
