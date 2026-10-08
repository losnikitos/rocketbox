ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def sign_in_as(user)
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    challenge = LoginChallenge.issue!(user.email)
    post(sign_in_otp_url, params: { email: user.email, otp: challenge[:code] })
    user
  ensure
    Rails.cache = previous_cache
  end

  TRANSFORMATION_KEYS = %i[kind body options style style_id shot_group layer_steps].freeze

  # Recipe attributes with its transformation's nested, as the recipe form sends them.
  def recipe_attributes(**attrs) = attrs.except(*TRANSFORMATION_KEYS).merge(transformation_attributes: attrs.slice(*TRANSFORMATION_KEYS))

  def new_recipe(**attrs) = Recipe.new(**recipe_attributes(**attrs))

  def create_recipe(**attrs) = new_recipe(**attrs).tap(&:save!)
end
