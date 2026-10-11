class EnableAndBandChatModels < ActiveRecord::Migration[8.1]
  def up
    { "openai" => { "gpt-6-luna" => 1, "gpt-6.1-sol" => 3 },
      "gemini" => { "gemini-3.5-flash-lite" => 1, "gemini-3.8-flash" => 2 },
      "xai" => { "grok-4.7" => 3 } }.each do |provider, bands|
      bands.each do |model_id, price_band|
        RubyLLM::ActiveRecord::Model.where(provider:, model_id:).update_all(enabled: true, price_band:)
      end
    end
  end
end
