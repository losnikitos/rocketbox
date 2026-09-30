class AddEnabledAndPositionToRubyLlmModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ruby_llm_models, :enabled, :boolean, default: false, null: false
    add_column :ruby_llm_models, :position, :integer

    up_only do
      RubyLLM::ActiveRecord::Model.reset_column_information
      %w[grok-imagine-image-2.0 grok-imagine-image-quality grok-imagine-image gpt-image-2 gpt-image-1.5 gpt-image-1-mini
         grok-imagine-video-1.5 grok-imagine-video].each.with_index(1) do |model_id, position|
        RubyLLM::ActiveRecord::Model.where(provider: %w[xai openai], model_id:).update_all(enabled: true, position:)
      end
    end
  end
end
