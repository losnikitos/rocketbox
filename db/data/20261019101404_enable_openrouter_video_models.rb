# frozen_string_literal: true

# OpenRouter image-to-video models for the Video generation picker.
class EnableOpenrouterVideoModels < ActiveRecord::Migration[8.1]
  MODELS = {
    1 => {
      "bytedance/seedance-1-5-pro" => "ByteDance: Seedance 1.5 Pro",
      "bytedance/seedance-2.0-fast" => "ByteDance: Seedance 2.0 Fast"
    },
    2 => {
      "bytedance/seedance-2.5" => "ByteDance: Seedance 2.5",
      "kwaivgi/kling-v3.0-std" => "Kling: Video v3.0 Standard",
      "kwaivgi/kling-v3.0-pro" => "Kling: Video v3.0 Pro",
      "runway/gen-4.5" => "Runway: Gen-4.5"
    },
    3 => {
      "black-forest-labs/flux-3-video" => "Black Forest Labs: FLUX 3 Video"
    }
  }.freeze

  def up
    MODELS.each do |price_band, names|
      names.each do |model_id, name|
        model = RubyLLM::ActiveRecord::Model.find_or_initialize_by(provider: "openrouter", model_id:)
        model.update!(
          name:,
          modalities: { "input" => %w[text image], "output" => %w[video] },
          enabled: true,
          price_band:
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
