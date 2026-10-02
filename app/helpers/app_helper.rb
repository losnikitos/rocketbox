# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected, count = nil]
  def app_nav
    case controller_path
    when "accounts/library"
      counts = Current.account.library_media.where(collection: @collection).group(:media_type_id).count
      type = @media ? @media.media_type&.slug : params[:type]
      tabs = [
        [ library_collection_path(@collection), "All", type.blank?, counts.values.sum ],
        :separator,
        *MediaType.ordered.map { |t| [ library_collection_path(@collection, type: t.slug), t.name, type == t.slug, counts[t.id].to_i ] }
      ]
      return [ :photobank, "Photobank", tabs ] if @collection == "photobank"

      [ :library, "Inbox", [
        *tabs,
        :separator,
        [ library_uploads_path(type: "reviews"), "Reviews", params[:type] == "reviews", Current.account.reviews.active.media_attachments.count ]
      ] ]
    when "accounts/generations"
      [ :library, "Generate", [] ]
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
    when "accounts/prompts"
      index = action_name == "index"
      counts = Prompt.group(:media_type_id).count
      [ :prompts, "Prompts", [
        [ prompts_path, "All", index && params[:media_type].blank?, counts.values.sum ],
        :separator,
        *MediaType.ordered.map { |t| [ prompts_path(media_type: t.slug), t.name, index && params[:media_type] == t.slug, counts[t.id].to_i ] }
      ] ]
    when "accounts/recipes", "accounts/recipe_posts"
      [ :recipes, "Recipes", [] ]
    when "accounts/styles"
      [ :styles, "Styles", [] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end

  def library_collection_path(collection, **params)
    collection == "photobank" ? library_photobank_path(**params) : library_uploads_path(**params)
  end

  def library_item_path(media, **params)
    media.photobank? ? library_photobank_media_path(media, **params) : library_upload_path(media, **params)
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
