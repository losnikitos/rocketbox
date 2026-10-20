# frozen_string_literal: true

# Seed product-level video caps (frame roles + option allowlists) onto OpenRouter video models' metadata.
# Prefers a live GET /api/v1/videos/models; falls back to the snapshot below when the key or network is missing.
class SyncOpenrouterVideoCapabilities < ActiveRecord::Migration[8.1]
  OUR_ASPECT = %w[9:16 1:1 16:9].freeze
  OUR_RESOLUTION = %w[720p 1080p].freeze
  OUR_DURATION = %w[4 5 6 8 10].freeze
  WITH_REFS = GenerationOptions::VIDEO_WITH_REFS

  # Offline snapshot of the seven enabled models (intersected with our picker shortlists).
  SNAPSHOT = {
    "bytedance/seedance-1-5-pro" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p 1080p],
      "duration" => %w[4 5 6 8 10]
    },
    "bytedance/seedance-2.0-fast" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p],
      "duration" => %w[4 5 6 8 10]
    },
    "bytedance/seedance-2.5" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p],
      "duration" => %w[4 5 6 8 10]
    },
    "kwaivgi/kling-v3.0-std" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p],
      "duration" => %w[4 5 6 8 10]
    },
    "kwaivgi/kling-v3.0-pro" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p],
      "duration" => %w[4 5 6 8 10]
    },
    "runway/gen-4.5" => {
      "frame_roles" => %w[first],
      "aspect_ratio" => %w[9:16 16:9],
      "resolution" => %w[720p],
      "duration" => %w[4 5 6 8 10]
    },
    "black-forest-labs/flux-3-video" => {
      "frame_roles" => %w[first last refs],
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p 1080p],
      "duration" => %w[5 6 8 10]
    }
  }.freeze

  def up
    caps = fetch_caps || SNAPSHOT
    caps.each do |model_id, video|
      model = RubyLLM::ActiveRecord::Model.find_by(provider: "openrouter", model_id:)
      next unless model

      model.update!(metadata: model.metadata.to_h.merge("video" => video))
    end
  end

  def down
    SNAPSHOT.each_key do |model_id|
      model = RubyLLM::ActiveRecord::Model.find_by(provider: "openrouter", model_id:)
      next unless model

      model.update!(metadata: model.metadata.to_h.except("video"))
    end
  end

  private

    def fetch_caps
      key = Rails.application.credentials.dig(:openrouter, :api_key).presence or return
      require "net/http"
      require "json"
      uri = URI("https://openrouter.ai/api/v1/videos/models")
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.get(uri, "Authorization" => "Bearer #{key}")
      end
      return unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body).fetch("data", []).filter_map do |row|
        id = row["id"]
        next unless SNAPSHOT.key?(id)

        [ id, video_caps_from(row) ]
      end.to_h.presence
    rescue StandardError => e
      say "OpenRouter video models unreachable (#{e.class}: #{e.message}); using snapshot"
      nil
    end

    def video_caps_from(row)
      roles = Array(row["supported_frame_images"]).filter_map do |frame|
        { "first_frame" => "first", "last_frame" => "last" }[frame]
      end
      roles << "refs" if WITH_REFS.include?(row["id"])
      {
        "frame_roles" => roles.uniq.presence || %w[first],
        "aspect_ratio" => Array(row["supported_aspect_ratios"]) & OUR_ASPECT,
        "resolution" => Array(row["supported_resolutions"]).map(&:to_s) & OUR_RESOLUTION,
        "duration" => Array(row["supported_durations"]).map(&:to_s) & OUR_DURATION
      }.transform_values { it.presence }.compact
    end
end
