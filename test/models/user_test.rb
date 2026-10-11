require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "destroy removes all linked data" do
    user = users(:lazaro_nixon)
    user.sessions.create!
    media = user.library_media.create!(kind: "photo", file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    user.rubrics.create!(name: "Daily", schedule: "every day at 9am", folder: folders(:inbox)).posts.create!(library_media: media)
    user.incoming_messages.create!(channel: "whatsapp", payload: { "x" => 1 })
    user.links.create!(url: "https://example.com").crawls.create!(provider: "firecrawl", data_instruction: "x")
      .suggestions.create!(key: "phone", value: "1")

    user.destroy!

    [ Session, LibraryMedia, Rubric, IncomingMessage, Link, Subscription ].each do |model|
      assert_empty model.where(user_id: user.id), model.name
    end
    assert_equal 0, RubricPost.count + Crawl.count + Suggestion.count
  end
end
