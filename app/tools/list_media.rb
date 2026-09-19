# frozen_string_literal: true

class ListMedia < RubyLLM::Tool
  description "Lists media in the user's Rocketbox library (count + items)."

  def initialize(user:)
    @user = user
  end

  def execute
    return { error: "No Rocketbox account linked. Set your Telegram user id in Account → Integrations." } if @user.nil?

    uploads = @user.telegram_uploads.order(created_at: :desc)
    {
      count: uploads.count,
      items: uploads.limit(50).map { |u|
        { id: u.id, kind: u.kind, created_at: u.created_at.iso8601 }
      }
    }
  end
end
