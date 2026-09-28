# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected, count = nil]
  def app_nav
    case controller_path
    when "accounts/library"
      counts = Current.account.library_media.group(:media_type).count
      [ :library, "Library", [
        [ library_uploads_path, "All", params[:type].blank?, counts.values.sum ],
        :separator,
        *LibraryMedia.media_types.keys.map { |t| [ library_uploads_path(type: t), t.titleize, params[:type] == t, counts[t].to_i ] }
      ] ]
    when "accounts/posts"
      [ :posts, "Posts", posts_tabs ]
    when "accounts/business"
      [ :business, "Business", [] ]
    when "accounts/links"
      [ :links, "Links", [] ]
    when "accounts/instagram"
      [ :instagram, "Instagram", [] ]
    when "accounts/subscriptions"
      [ :subscription, "Subscription", [] ]
    when "accounts/settings"
      [ :profile, "Profile", [] ]
    when "accounts/onboarding"
      [ :onboarding, "Onboarding", [
        [ onboarding_path, "Steps", params[:tab] != "media" ],
        [ onboarding_path(tab: "media"), "Media", params[:tab] == "media" ]
      ] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end

  def posts_tabs
    index = action_name == "index"
    [
      [ instagram_posts_path, "All", index && params[:kind].blank? ],
      :separator,
      *Accounts::PostsController::KINDS.map { |kind| [ instagram_posts_path(kind:), kind.capitalize, index && params[:kind] == kind ] }
    ]
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
