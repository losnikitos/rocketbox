ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

# ffmpeg is mocked unless RENDER_MEDIA=1: each call copies a canned file of its output's extension to its output path.
module MockFfmpeg
  def ffmpeg!(*args) = FileUtils.cp(Rails.root.join("test/fixtures/files/rendered#{File.extname(args.last)}"), args.last)
end
Transformation::Type.prepend(MockFfmpeg) unless ENV["RENDER_MEDIA"].present?

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def render_media? = ENV["RENDER_MEDIA"].present?

  def sign_in_as(user)
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    challenge = LoginChallenge.issue!(user.email)
    post(sign_in_otp_url, params: { email: user.email, otp: challenge[:code] })
    user
  ensure
    Rails.cache = previous_cache
  end

  # A workflow feeding the `input` folder into a step of `transformation`, landing in `output` (Ready if none).
  def create_workflow(name, input:, transformation:, output: nil)
    Workflow.create!(name:).tap do |workflow|
      step = workflow.nodes.create!(transformation:)
      workflow.edges.create!(from: workflow.nodes.create!(folder: input), to: step)
      workflow.edges.create!(from: step, to: workflow.nodes.create!(folder: output)) if output
    end
  end
end
