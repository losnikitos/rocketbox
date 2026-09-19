RubyLLM.configure do |config|
  config.xai_api_key = Rails.application.credentials.dig(:xai, :api_key)
  config.default_model = "grok-4.6"
  config.logger = Rails.logger
end
