# frozen_string_literal: true

require "test_helper"

class WakeAgentJobTest < ActiveJob::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    @photo = @user.library_media.create!(kind: "photo", folder: folders(:inbox))
    @sent = sent = []
    @asked = asked = []
    @original_send = WhatsappCloud.method(:send_text)
    @original_reply = RocketboxAgent.method(:reply)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
    RocketboxAgent.define_singleton_method(:reply) { |_, text| asked << text; Struct.new(:content).new("What's the business called?") }
  end

  teardown do
    Rails.cache = @previous_cache
    WhatsappCloud.define_singleton_method(:send_text, @original_send)
    RocketboxAgent.define_singleton_method(:reply, @original_reply)
  end

  test "stays quiet while a step is running and speaks once it is quiet" do
    token = "wake-token"
    Rails.cache.write(WakeAgentJob.cache_key(@user), token)
    running = TransformationRun.create!(result: @photo, status: "running")

    WakeAgentJob.perform_now(@user.id, token)
    assert_empty @sent

    running.update!(status: "complete")
    WakeAgentJob.perform_now(@user.id, token)
    assert_equal [ "What's the business called?" ], @sent
    assert_equal [ WakeAgentJob::TRIGGER ], @asked
  end

  test "a stale token does not speak" do
    Rails.cache.write(WakeAgentJob.cache_key(@user), "newer")

    WakeAgentJob.perform_now(@user.id, "older")

    assert_empty @sent
  end

  test "a quiet settled run schedules a wake and one that already texts the owner does not" do
    workflow = Workflow.create!(name: "Quiet card")
    run = workflow.runs.create!(status: "started")
    run.step_runs.create!(result: @photo, status: "complete")

    assert_enqueued_with(job: WakeAgentJob) { run.notify_settled! }

    approval = Transformation.create!(name: "Approval", kind: "approval", body: "Publish?")
    loud = Workflow.create!(name: "Loud reel").runs.create!(status: "started")
    loud.step_runs.new(transformation: approval, result: @photo, status: "complete").save!(validate: false)

    assert_no_enqueued_jobs only: WakeAgentJob do
      loud.notify_settled!
    end
  end
end
