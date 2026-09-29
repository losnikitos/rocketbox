require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "destroy removes all linked data" do
    user = users(:lazaro_nixon)
    user.sessions.create!
    media = user.library_media.create!(kind: "photo", file: { io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg" })
    user.smm_posts.create!(recipe: recipes(:cinematic), smm_post_media_items: [ SmmPostMediaItem.new(library_media: media) ])
    user.incoming_messages.create!(channel: "whatsapp", payload: { "x" => 1 })
    user.links.create!(url: "https://example.com").crawls.create!(provider: "firecrawl", data_instruction: "x")
      .suggestions.create!(key: "phone", value: "1")

    user.destroy!

    [ Session, LibraryMedia, SmmPost, IncomingMessage, Link, Subscription ].each do |model|
      assert_empty model.where(user_id: user.id), model.name
    end
    assert_equal 0, SmmPostMediaItem.count + Crawl.count + Suggestion.count
  end
end
