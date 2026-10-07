RubyLLM.configure do |config|
  config.xai_api_key = Rails.application.credentials.dig(:xai, :api_key)
  config.openai_api_key = Rails.application.credentials.dig(:openai, :api_key)
  config.gemini_api_key = Rails.application.credentials.dig(:gemini, :api_key)
  config.default_model = "grok-4.6"
  config.default_image_model = "grok-imagine-image-2.0"
  config.logger = Rails.logger
end

# ponytail: ruby_llm 2.0.0 sends Veo's reference image as `inlineData`, which the Gemini API rejects; drop on a gem fix.
RubyLLM::Protocols::Gemini::Videos.module_eval do
  private def render_video_image(image) = { bytesBase64Encoded: image.encoded, mimeType: image.mime_type }
end

# ponytail: ruby_llm 2.0.0 only sends `gemini-*-image` ids to generateContent, so `gemini-nano-banana-2.1` would hit
# Imagen's `predict`; drop on a gem fix.
RubyLLM::Protocols::Gemini::Images.module_eval do
  private def gemini_image_model?(model) = model_id(model).downcase.match?(/nano-?banana|\Agemini-.*-image/)
end

# RubyLLM's AR classes inherit from ::ActiveRecord::Base, so they miss the
# ransack allowlist on ApplicationRecord (needed by Active Admin filters).
Rails.application.config.to_prepare do
  [
    RubyLLM::ActiveRecord::Model,
    RubyLLM::ActiveRecord::ToolCall,
    RubyLLM::ActiveRecord::Usage,
    RubyLLM::ActiveRecord::Batch
  ].each do |klass|
    klass.class_eval do
      def self.ransackable_attributes(_auth_object = nil) = column_names
      def self.ransackable_associations(_auth_object = nil) = reflect_on_all_associations.map { |a| a.name.to_s }
    end
  end

  # Models offered in the app, in the order set by drag-and-drop in Active Admin; unsorted ones go last.
  RubyLLM::ActiveRecord::Model.define_singleton_method(:enabled) do
    where(enabled: true).order(arel_table[:position].asc.nulls_last, :id)
  end

  # A refresh writes empty modalities for models only the provider API lists (not models.dev);
  # keep the ones set by hand, or image models fall back to type :chat.
  RubyLLM::ActiveRecord::Model.before_update do
    self.modalities = modalities_was if modalities.values.flatten.empty? && modalities_was.present?
  end
end
