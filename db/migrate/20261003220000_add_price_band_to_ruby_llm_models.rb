class AddPriceBandToRubyLlmModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ruby_llm_models, :price_band, :integer

    up_only do
      RubyLLM::ActiveRecord::Model.reset_column_information
      { 1 => %w[gemini-3.1-flash-lite-image],
        2 => %w[gpt-image-2.5-flare gpt-image-2.5-sunburst gemini-3.1-flash-image],
        3 => %w[gemini-3-pro-image gpt-image-2] }.each do |price_band, model_id|
        RubyLLM::ActiveRecord::Model.where(model_id:).update_all(price_band:)
      end
    end
  end
end
