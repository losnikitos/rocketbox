# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected]
  def app_nav
    case controller_path
    when "accounts/library"
      [ :library, "Library", [
        [ library_uploads_path, "Uploads", action_name == "uploads" ]
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
    when "accounts/settings", "accounts/integrations", "accounts/subscriptions"
      [ :profile, "Profile", [
        [ profile_settings_path, "Settings", controller_path == "accounts/settings" ],
        [ profile_integrations_path, "Integrations", controller_path == "accounts/integrations" ],
        [ profile_subscription_path, "Subscription", controller_path == "accounts/subscriptions" ]
      ] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end
end
