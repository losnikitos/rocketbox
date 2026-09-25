RubyLLM.configure do |config|
  config.xai_api_key = Rails.application.credentials.dig(:xai, :api_key)
  config.default_model = "grok-4.6"
  config.logger = Rails.logger
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
end
