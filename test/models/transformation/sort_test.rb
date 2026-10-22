# frozen_string_literal: true

require "test_helper"

class Transformation::SortTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:lazaro_nixon)
    @original_chat = RubyLLM.method(:chat)
    @workflow = Workflow::InboxSort.ensure!
    @inbox = @workflow.nodes.find { it.folder == Folder.inbox }
    @sort = @workflow.nodes.find(&:step?)
  end

  teardown { RubyLLM.define_singleton_method(:chat, @original_chat) }

  test "type is registered under Control and relocates" do
    type = Transformation::Sort
    assert_includes Transformation::Type.all, type
    assert_equal Transformation::Control, type.group
    assert type.relocates?
    assert type.ai?
    assert type.chat?
    assert type.single?
    assert_not type.waits?
    assert Rails.root.join("app/assets/images", type.cover).exist?
  end

  test "a photo landing in the inbox root moves to the subfolder the model picks among connected folders" do
    @sort.transformation.update!(body: Transformation::Sort::DEFAULT_BODY) if @sort.transformation.body.blank?
    asked = stub_chat { { "folder" => "interior" } }

    media = perform_enqueued_jobs { land }

    assert_equal folders(:interior), media.reload.folder
    assert_equal media, media.transformation_run.result
    assert_equal @sort, media.transformation_run.workflow_node
    schema, message, with = asked.sole
    assert_equal @sort.workflow.edges.select { it.from_id == @sort.id }.map { it.to.folder.slug }.sort,
      schema.dig(:properties, :folder, :enum).sort
    assert_includes message, Transformation::Sort::DEFAULT_BODY.lines.first
    assert_includes message, "- misc: Misc"
    assert_equal media.file.blob, with.blob
  end

  test "it stays in the inbox root when the model fails" do
    stub_chat { raise RubyLLM::Error, "boom" }

    media = perform_enqueued_jobs { land }

    assert_equal folders(:inbox), media.reload.folder
    assert media.transformation_run.failed?
  end

  test "inbox start does not take media already in a subfolder" do
    media = @user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })

    assert_not @inbox.takes?(media)
    assert_not @inbox.include_subfolders?
  end

  test "drop destroys the sort run without destroying the media" do
    stub_chat { { "folder" => "misc" } }
    media = perform_enqueued_jobs { land }
    run = media.transformation_run
    assert_equal "complete", run.status

    run.workflow_run.send(:drop, run)

    assert_not TransformationRun.exists?(run.id)
    assert LibraryMedia.exists?(media.id)
    assert_equal folders(:misc), media.reload.folder
  end

  test "original stops when the sort result is the source" do
    stub_chat { { "folder" => "logo" } }
    media = perform_enqueued_jobs { land }

    assert_equal media, media.original
  end

  private

    def land
      @user.library_media.create!(kind: "photo",
        file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    end

    def stub_chat(&reply)
      asked = []
      chat = Object.new
      chat.define_singleton_method(:with_schema) { |schema| asked << [ schema ] and self }
      chat.define_singleton_method(:ask) { |message, with:| asked.last.push(message, with) and Struct.new(:parsed).new(reply.call) }
      RubyLLM.define_singleton_method(:chat) { |**| chat }
      asked
    end
end
