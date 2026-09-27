# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected]
  def app_nav
    case controller_path
    when "accounts/library"
      [ :library, "Library", [
        [ library_uploads_path, "Uploads", true ]
      ] ]
    when "accounts/smm"
      [ :smm, "SMM", [
        [ smm_reels_path, "Reels", action_name == "reels" ],
        [ smm_stories_path, "Stories", action_name == "stories" ],
        [ smm_posts_path, "Posts", false ]
      ] ]
    when "accounts/posts"
      [ :smm, "SMM", [
        [ smm_reels_path, "Reels", false ],
        [ smm_stories_path, "Stories", false ],
        [ smm_posts_path, "Posts", true ]
      ] ]
    when "accounts/business"
      [ :business, "Business", [] ]
    when "accounts/integrations"
      [ :integrations, "Integrations", [] ]
    when "accounts/subscriptions"
      [ :subscription, "Subscription", [] ]
    when "accounts/settings"
      [ :profile, "Profile", [] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end

  def smm_post_status_text_class(status)
    case status.to_s
    when "ready" then "text-signal-green"
    when "published" then "text-rocket"
    when "failed" then "text-signal-red"
    when "generating" then "text-ink-700"
    else "text-ink-500"
    end
  end

  def smm_post_status_pill_class(status)
    bg = case status.to_s
    when "ready" then "bg-signal-green/15"
    when "published" then "bg-rocket/15"
    when "failed" then "bg-signal-red/15"
    when "generating" then "bg-signal-yellow/30"
    else "bg-ink-900/5"
    end
    "#{bg} #{smm_post_status_text_class(status)}"
  end
end
