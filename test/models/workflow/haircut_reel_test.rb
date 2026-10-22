# frozen_string_literal: true

require "test_helper"

class Workflow::HaircutReelTest < ActiveSupport::TestCase
  test "seeds one autorun path from haircuts through publish, and wires haircuts into inbox sort" do
    Workflow::InboxSort.ensure!

    assert_difference -> { Workflow.count } => 1 do
      @workflow = Workflow::HaircutReel.ensure!
    end
    assert_no_difference -> { WorkflowNode.count } do
      assert_equal @workflow, Workflow::HaircutReel.ensure!
    end

    assert @workflow.autorun
    assert @workflow.built_in?
    folder = Folder.inbox.children.find_by!(slug: "haircuts")
    kinds = @workflow.nodes.order(:x).filter_map { it.transformation&.kind }
    assert_equal %w[collect gm_visuals approval publish], kinds
    reel, approval, publish = @workflow.nodes.order(:x).filter_map(&:transformation).drop(1)
    assert_equal "We're preparing a reel", reel.body
    assert_equal [ "Your reel is ready. Publish?", "Publish" ], [ approval.body, approval.options["button"] ]
    assert_equal [ "Publishing to Instagram...", "Your reel has been published", "View on Instagram" ],
      [ publish.body, publish.options["done"], publish.options["button"] ]
    assert @workflow.nodes.exists?(folder:, media_type: "image", take: 2)
    assert Workflow.find_by!(slug: "inbox-sort").nodes.exists?(folder:)
  end
end
