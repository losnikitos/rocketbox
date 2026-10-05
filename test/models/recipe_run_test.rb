# frozen_string_literal: true

require "test_helper"

class RecipeRunTest < ActiveSupport::TestCase
  test "recent_for lists the user's last 5 recipe runs, newest first, without manual versions" do
    user = users(:lazaro_nixon)
    runs = 6.times.map { |i| make_run(user, recipes(:cinematic), created_at: i.hours.ago) }
    make_run(user, nil)
    make_run(users(:admin_user), recipes(:cinematic))

    assert_equal runs.first(5), RecipeRun.recent_for(user).to_a
  end

  private

    def make_run(user, recipe, created_at: Time.current)
      media = LibraryMedia.create!(kind: "photo", folder: folders(:ready), user:)
      RecipeRun.new(recipe:, generated_media: media, created_at:).tap { it.save!(validate: false) }
    end
end
