# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected, count = nil]
  def app_nav
    case controller_path
    when "accounts/overview"
      [ :overview, "Overview", [] ]
    when "accounts/folders", "accounts/library"
      [ :folders, (@folder || @media&.folder)&.name || "Media", [] ]
    when "accounts/posts"
      [ :posts, "Posts", posts_tabs ]
    when "accounts/business"
      [ :business, "Business", [] ]
    when "accounts/calendar"
      [ :calendar, "Calendar", [] ]
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
    when "accounts/shots"
      index = action_name == "index"
      counts = Shot.group(:group).count
      [ :shots, "Shots", [
        [ shots_path, "All", index && params[:group].blank?, counts.values.sum ],
        :separator,
        *counts.sort.map { |group, count| [ shots_path(group:), group, index && params[:group] == group, count ] }
      ] ]
    when "accounts/layers"
      [ :layers, "Layers", [] ]
    when "accounts/recipes", "accounts/recipe_runs"
      index = controller_path == "accounts/recipes" && action_name == "index"
      recipes = Recipe.all.to_a
      [ :recipes, "Recipes", [
        [ recipes_path, "All", index && params[:source].blank?, recipes.size ],
        :separator,
        *Recipe.by_source(recipes).flat_map do |group|
          source = group.first.source
          [ (:separator if source == "multiple"), [ recipes_path(source:), group.first.source_label, index && params[:source] == source, group.size ] ].compact
        end
      ] ]
    when "accounts/features"
      [ :features, "Features", [] ]
    when "accounts/styles"
      [ :styles, "Styles", [] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end

  def folder_path(folder, **params)
    library_folders_path(*[ folder.root.slug, (folder.slug unless folder.root?) ].compact, **params)
  end

  def delete_folder_confirm(folder)
    "Delete #{folder.name}? " + (folder.parent ? "Its media moves to #{folder.parent.name}." : "Only empty folders can be deleted.")
  end

  def folder_color(folder)
    folder&.root&.slug == "inbox" ? "text-emerald-500" : "text-sky-400"
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
