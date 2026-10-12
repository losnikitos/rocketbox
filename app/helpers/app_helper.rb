# frozen_string_literal: true

module AppHelper
  # Returns [section, title, tabs] where tabs are [path, label, selected, count = nil]
  def app_nav
    case controller_path
    when "accounts/recent"
      [ :recent, "Recent", [] ]
    when "accounts/folders", "accounts/library"
      [ :folders, (@folder || @media&.folder)&.name || "Media", [] ]
    when "accounts/rubrics"
      view = ->(name) { url_for(request.query_parameters.merge("view" => name).compact) }
      [ :schedule, "Schedule", [
        [ view.(nil), "Week", params[:view] != "month" ],
        [ view.("month"), "Month", params[:view] == "month" ]
      ] ]
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
    when "accounts/prompts"
      [ :folders, @prompt&.folder&.name || "Prompts", [] ]
    when "accounts/layers"
      [ :layers, "Layers", [] ]
    when "accounts/workflows"
      [ :workflows, "Workflows", [] ]
    else
      [ nil, "Rocketbox", [] ]
    end
  end

  def folder_path(folder, **params)
    library_folders_path(*[ folder.root.slug, (folder.slug unless folder.root?) ].compact, **params)
  end

  def delete_folder_confirm(folder)
    "Delete #{folder.name}? " + (folder.parent ? "Its #{folder.media? ? "media" : folder.kind.pluralize} move to #{folder.parent.name}." : "Only empty folders can be deleted.")
  end

  FOLDER_COLORS = { "sky" => "text-sky-400", "emerald" => "text-emerald-500", "amber" => "text-amber-400", "red" => "text-red-500",
                    "rose" => "text-rose-400", "violet" => "text-violet-400", "slate" => "text-slate-400" }.freeze

  NOTE_COLORS = { "sky" => "border-sky-200 bg-sky-50", "emerald" => "border-emerald-200 bg-emerald-50", "amber" => "border-amber-200 bg-amber-50", "red" => "border-red-200 bg-red-50",
                  "rose" => "border-rose-200 bg-rose-50", "violet" => "border-violet-200 bg-violet-50", "slate" => "border-slate-200 bg-slate-50" }.freeze

  def folder_color(folder) = FOLDER_COLORS[folder&.color || "sky"]

  # A hover badge opening the item in the library in a new tab; its parent needs `group relative`.
  def open_in_library(item, css = "top-1 right-1")
    path = case item
    when LibraryMedia then library_item_path(item)
    when Prompt then edit_prompt_path(item)
    when Review then reviews_path(archived: (1 if item.archived?), anchor: dom_id(item))
    end
    link_to path, target: "_blank", rel: "noopener", title: "Open in library", aria: { label: "Open in library" },
      class: "absolute #{css} flex size-6 items-center justify-center rounded-full bg-white/90 text-ink-700 opacity-0 shadow-sm group-hover:opacity-100 focus-visible:opacity-100 hover:text-ink-900 focus-visible:outline-2 focus-visible:outline-rocket" do
      heroicon "folder", variant: :micro, options: { class: "size-3.5", "aria-hidden": true }
    end
  end

  # A rubric post's status: publishing, published or failed.
  def rubric_post_status_pill_class(status)
    color = { "scheduled" => "bg-ink-900/5 text-ink-600", "publishing" => "bg-signal-yellow/20 text-ink-700", "published" => "bg-rocket/15 text-rocket",
              "failed" => "bg-signal-red/10 text-signal-red" }[status.to_s]
    "rounded-full px-2 py-0.5 text-xs font-medium #{color}"
  end

  # A workflow run's or step run's status: draft, running, complete or failed.
  def run_status_pill_class(status)
    color = { "draft" => "bg-ink-900/5 text-ink-600", "running" => "bg-signal-yellow/20 text-ink-700",
              "complete" => "bg-signal-green/15 text-ink-900", "failed" => "bg-signal-red/10 text-signal-red" }[status.to_s]
    "rounded-full px-2 py-0.5 text-xs font-medium #{color}"
  end
end
