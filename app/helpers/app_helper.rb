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
        *LibraryMedia.media_types.keys.map { |t| [ library_uploads_path(type: t), t.titleize, params[:type] == t, counts[t].to_i ] },
        :separator,
        [ library_uploads_path(type: "reviews"), "Reviews", params[:type] == "reviews", Current.account.reviews.active.media_attachments.count ]
      ] ]
    when "accounts/posts"
      [ :posts, "Posts", posts_tabs ]
    when "accounts/business"
      [ :business, "Business", [] ]
    when "accounts/services"
      [ :services, "Services", [] ]
    when "accounts/links"
      [ :links, "Links", [] ]
    when "accounts/reviews"
      active = Current.account.reviews.active.group(:source).count
      photos = params[:photos].present? && params[:archived].blank?
      source = params[:source] if params[:archived].blank? && !photos
      [ :reviews, "Reviews", [
        [ reviews_path, "All", params[:archived].blank? && !photos && source.blank?, active.values.sum ],
        *Review.sources.keys.filter_map { |s| [ reviews_path(source: s), s.humanize, source == s, active[s].to_i ] if active[s] || source == s },
        [ reviews_path(photos: 1), "Photos", photos, Current.account.reviews.active.with_media.count ],
        :separator,
        [ reviews_path(archived: 1), "Archived", params[:archived].present?, Current.account.reviews.archived.count ]
      ] ]
    when "accounts/instagram"
      [ :instagram, "Your profile", [] ]
    when "accounts/whatsapp"
      [ :whatsapp, "WhatsApp", [] ]
    when "accounts/subscriptions"
      [ :subscription, "Subscription", [] ]
    when "accounts/settings"
      [ :profile, "Profile", [] ]
    when "accounts/onboarding"
      [ :onboarding, "Onboarding", [
        [ onboarding_path, "Steps", params[:tab] != "media" ],
        [ onboarding_path(tab: "media"), "Media", params[:tab] == "media" ]
      ] ]
    when "accounts/admin"
      [ :admin, "Admin", [] ]
    when "accounts/recipes"
      [ :recipes, "Recipes", [] ]
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

  # [[node, count], …] in run order, consecutive steps of the same node merged.
  def workflow_scheme(workflow)
    workflow&.steps.to_a.map(&:node).chunk_while { _1 == _2 }.map { [ it.first, it.size ] }
  end

  # Data types in the workflow picker, one fixed color each: [label, icon, classes].
  SCHEME_BOXES = {
    image: [ "Image", "photo", "border-green-200 bg-green-50 text-green-800" ],
    prompt: [ "Prompt", "sparkles", "border-blue-200 bg-blue-50 text-blue-800" ],
    video: [ "Video", "film", "border-violet-200 bg-violet-50 text-violet-800" ],
    text: [ "Text", "chat-bubble-bottom-center-text", "border-amber-200 bg-amber-50 text-amber-800" ]
  }.freeze

  # [[label, icon, classes], …] e.g. "2 × Image", "Prompt", "2 × Image"; the one recipe prompt is never multiplied.
  def workflow_boxes(workflow)
    workflow_scheme(workflow).flat_map do |node, count|
      node::SCHEME.map do |type|
        label, icon, css = SCHEME_BOXES.fetch(type)
        [ count > 1 && type != :prompt ? "#{count} × #{label}" : label, icon, css ]
      end
    end
  end
end
