# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected, count = nil]
  def app_nav
    case controller_path
    when "accounts/overview"
      [ :overview, "Overview", [] ]
    when "accounts/folders"
      [ :folders, "Folders", [] ]
    when "accounts/library"
      if @collection == "ready"
        ready = Current.account.library_media.ready
        counts = ready.joins(:recipe_run).group("recipe_runs.recipe_id").count
        recipe_id = @media ? @media.recipe_run&.recipe_id : params[:recipe]&.to_i
        return [ :ready, "Ready", [
          [ library_ready_path, "All", recipe_id.blank?, ready.count ],
          :separator,
          *Recipe.ordered.map { |r| [ library_ready_path(recipe: r.id), r.name, recipe_id == r.id, counts[r.id].to_i ] }
        ] ]
      end

      counts = Current.account.library_media.where(collection: @collection).group(:tag_id).count
      slug = @media ? @media.tag&.slug : params[:tag]
      tabs = [
        [ library_collection_path(@collection), "All", slug.blank? && params[:type].blank?, counts.values.sum ],
        :separator,
        *Tag.ordered.map { |t| [ library_collection_path(@collection, tag: t.slug), t.name, slug == t.slug, counts[t.id].to_i ] }
      ]
      return [ :photobank, "Photobank", tabs ] if @collection == "photobank"

      [ :library, "Inbox", [
        *tabs,
        :separator,
        [ library_uploads_path(type: "reviews"), "Reviews", params[:type] == "reviews", Current.account.reviews.active.media_attachments.count ]
      ] ]
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
        [ recipes_path, "All", index && params[:folder].blank?, recipes.size ],
        :separator,
        *LibraryMedia.collections.keys.map do |folder|
          [ recipes_path(folder:), folder.humanize, index && params[:folder] == folder, recipes.count { it.reads?(folder) } ]
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

  def library_collection_path(collection, **params)
    case collection
    when "photobank" then library_photobank_path(**params)
    when "ready" then library_ready_path(**params)
    else library_uploads_path(**params)
    end
  end

  def library_item_path(media, **params)
    case media.collection
    when "photobank" then library_photobank_media_path(media, **params)
    when "ready" then library_ready_media_path(media, **params)
    else library_upload_path(media, **params)
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
