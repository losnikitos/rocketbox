# frozen_string_literal: true

require "test_helper"

class Transformation::ApprovalTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:lazaro_nixon)
    @photo = @user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img-bytes"), filename: "shot.jpg", content_type: "image/jpeg" })
    @approval = Transformation.create!(name: "Approval", kind: "approval")
  end

  test "type is registered under Control and waits" do
    type = Transformation::Approval
    assert_includes Transformation::Type.all, type
    assert_equal Transformation::Control, type.group
    assert type.waits?
    assert type.single?
    assert Rails.root.join("app/assets/images", type.cover).exist?
  end

  test "start! waits without GenerateJob and notifies WhatsApp when linked" do
    @user.update!(whatsapp_phone: "15551234567")
    sent = []
    original = WhatsappCloud.method(:send_buttons)
    WhatsappCloud.define_singleton_method(:send_buttons) { |**args| sent << args }

    assert_no_enqueued_jobs only: GenerateJob do
      @run = @approval.run!(items: [ @photo ], folder: folders(:ready))
    end

    assert_equal "waiting", @run.status
    assert_not @run.generated_media.file.attached?
    assert_equal 1, sent.size
    assert_equal "15551234567", sent.first[:to]
    assert_equal "image", sent.first[:header][:type]
    assert_match %r{\Ahttps?://}, sent.first[:header][:link]
    assert_equal "Approve this for posting?", sent.first[:body]
    assert_equal({ "approval:approve:#{@run.id}" => "Approve", "approval:reject:#{@run.id}" => "Reject" }, sent.first[:buttons])
  ensure
    WhatsappCloud.define_singleton_method(:send_buttons, original)
  end

  test "video approval uploads the file and sends that WhatsApp media id" do
    @user.update!(whatsapp_phone: "15551234567")
    video = @user.library_media.create!(kind: "video", folder: folders(:interior),
      file: { io: StringIO.new("mp4"), filename: "reel.mp4", content_type: "video/mp4" })
    sent = []
    original_send = WhatsappCloud.method(:send_buttons)
    original_upload = WhatsappCloud.method(:upload_media)
    WhatsappCloud.define_singleton_method(:send_buttons) { |**args| sent << args }
    WhatsappCloud.define_singleton_method(:upload_media) { |*, **| "media-1" }

    run = @approval.run!(items: [ video ], folder: folders(:ready))

    assert_equal "waiting", run.status
    assert_equal({ type: "video", id: "media-1" }, sent.first[:header])
  ensure
    WhatsappCloud.define_singleton_method(:send_buttons, original_send) if original_send
    WhatsappCloud.define_singleton_method(:upload_media, original_upload) if original_upload
  end

  test "start! skips WhatsApp when the owner has no phone" do
    sent = []
    original = WhatsappCloud.method(:send_buttons)
    WhatsappCloud.define_singleton_method(:send_buttons) { |**args| sent << args }

    run = @approval.run!(items: [ @photo ], folder: folders(:ready))
    assert_equal "waiting", run.status
    assert_empty sent
  ensure
    WhatsappCloud.define_singleton_method(:send_buttons, original)
  end

  test "approve! pass-throughs the media and completes" do
    run = @approval.run!(items: [ @photo ], folder: folders(:ready))
    assert_equal "waiting", run.status

    run.approve!

    assert_equal "complete", run.reload.status
    assert_equal "img-bytes", run.generated_media.file.download
    assert_equal "approval_#{run.id}.jpg", run.generated_media.file.filename.to_s
  end

  test "reject! stops without completing" do
    run = @approval.run!(items: [ @photo ], folder: folders(:ready))
    run.reject!

    assert_equal "rejected", run.reload.status
    assert_not run.generated_media.file.attached?
  end

  test "approve! and reject! raise when not waiting" do
    run = @approval.run!(items: [ @photo ], folder: folders(:ready))
    run.approve!
    assert_raises(RuntimeError) { run.approve! }
    assert_raises(RuntimeError) { run.reject! }
  end

  test "in a workflow, approve advances and reject does not; approval never reuses" do
    workflow = Workflow.create!(name: "Gate")
    folder = workflow.nodes.create!(folder: folders(:interior))
    step = workflow.nodes.create!(transformation: @approval)
    next_step = workflow.nodes.create!(transformation_attributes: { kind: "smart_crop" })
    workflow.edges.create!(from: folder, to: step)
    workflow.edges.create!(from: step, to: next_step)

    run = workflow.latest_run
    run.start!(folder, @user)
    waiting = run.step_runs.sole
    assert_equal "waiting", waiting.status
    assert_equal 1, run.step_runs.size

    waiting.reject!
    assert_equal "rejected", waiting.reload.status
    assert_equal 1, run.step_runs.reload.size

    run.rerun!(step, @user)
    waiting = run.step_runs.sole
    assert_equal "waiting", waiting.status

    waiting.approve!
    assert_equal "complete", waiting.reload.status
    assert_equal 2, run.step_runs.reload.size
    assert_equal next_step, run.step_runs.last.workflow_node

    second = workflow.runs.create!
    second.start!(folder, @user)
    assert_equal "waiting", second.step_runs.sole.status
    assert_not_equal waiting.id, second.step_runs.sole.id
  end
end
