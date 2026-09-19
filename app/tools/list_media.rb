# frozen_string_literal: true

class ListMedia < RubyLLM::Tool
  description "Lists media in the user's Rocketbox library (count + items)."

  def initialize(user:)
    @user = user
  end

  def execute
    return { error: "No Rocketbox account linked. Set your Telegram user id in Account → Integrations." } if @user.nil?

    media = @user.library_media.order(created_at: :desc)
    {
      count: media.count,
      items: media.limit(50).map { |m|
        { id: m.id, kind: m.kind, created_at: m.created_at.iso8601 }
      }
    }
  end
end
