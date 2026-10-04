class EnableGeminiOmniAndBandVideoModels < ActiveRecord::Migration[8.1]
  def up
    RubyLLM::ActiveRecord::Model.where(provider: "gemini", model_id: "gemini-omni-1.1-flash")
      .update_all(enabled: true, modalities: { "input" => %w[text image video audio], "output" => %w[video] })
    { 1 => %w[veo-3.1-lite-generate-preview],
      2 => %w[veo-3.1-fast-generate-preview gemini-omni-1.1-flash],
      3 => %w[veo-3.1-generate-preview] }.each do |price_band, model_id|
      RubyLLM::ActiveRecord::Model.where(provider: "gemini", model_id:).update_all(price_band:)
    end
  end
end
