module ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  def tw_label_classes
    "mb-1 block text-sm font-medium text-ink-700"
  end

  def tw_input_classes
    "mt-1 block w-full rounded-lg border border-ink-900/15 bg-white px-3 py-2 text-ink-900 shadow-none placeholder:text-ink-400 focus:border-rocket focus:outline-none focus:ring-2 focus:ring-rocket/30 sm:text-sm"
  end

  # Segmented radio group: wrap labels (each holding an sr-only radio) in tw_segments_classes.
  def tw_segments_classes
    "flex rounded-xl border border-ink-900/15 bg-white"
  end

  # Pair with a before:inset-y-* for the divider height.
  def tw_segment_classes
    "relative flex-1 cursor-pointer rounded-xl border-2 border-transparent transition before:absolute before:-left-0.5 before:w-px before:bg-ink-900/15 first:before:hidden not-has-checked:hover:bg-stone-50 has-checked:border-rocket has-checked:bg-rocket/10 has-checked:before:hidden [:has(:checked)+&]:before:hidden has-focus-visible:outline-2 has-focus-visible:outline-rocket/30"
  end

  def tw_input_autosave_classes
    "#{tw_input_classes} pr-10"
  end

  # Wraps a field so autosave can show a green check inside on the right.
  def autosave_field(&)
    tag.div(class: "relative", data: { autosave_field: true }) do
      concat capture(&)
      concat(
        tag.span(
          class: "pointer-events-none absolute right-3 top-2.5 text-signal-green opacity-0 transition-opacity duration-150 data-saved:opacity-100",
          data: { autosave_target: "indicator" },
          aria: { hidden: true }
        ) { heroicon("check-circle", variant: :mini, options: { class: "size-5" }) }
      )
    end
  end

  def tw_btn_primary_classes
    "rb-btn-primary w-full"
  end

  def tw_btn_secondary_classes
    "rb-btn-ghost-on-light w-full"
  end

  def tw_alert_success_classes
    "mb-4 rounded-lg border border-signal-green/40 bg-ink-900/5 px-3 py-2 text-sm text-ink-900"
  end

  def tw_alert_error_classes
    "mb-4 rounded-lg border border-signal-red/35 bg-ink-900/5 px-3 py-2 text-sm text-ink-900"
  end

  def generation_status_class(generation)
    case generation.status
    when "succeeded" then "text-signal-green"
    when "failed" then "text-signal-red"
    else "text-ink-500"
    end
  end

  # Today / Yesterday / Thursday / Sun 20 Sep / Fri 31 Dec 2025
  def upload_day_label(date)
    today = Date.current
    return "Today" if date == today
    return "Yesterday" if date == today - 1
    return date.strftime("%A") if date >= today.beginning_of_week
    label = "#{date.strftime('%a')} #{date.day} #{date.strftime('%b')}"
    date.year == today.year ? label : "#{label} #{date.year}"
  end

  # ActiveAdmin: 64px thumbnails linking to each attachment.
  def admin_media_thumbs(attachments)
    thumb = "height: 64px; width: 64px; object-fit: cover;"
    tag.div(style: "display: flex; gap: 4px;") do
      safe_join(attachments.map do |attachment|
        link_to url_for(attachment), target: "_blank", rel: "noopener" do
          if attachment.image? then image_tag(url_for(attachment), style: thumb)
          elsif attachment.video? then image_tag(attachment.representation(resize_to_limit: [ 720, 720 ]), style: thumb)
          else attachment.filename.to_s
          end
        end
      end)
    end
  end

  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      strikethrough: true,
      superscript: true,
      tables: true
    )
    sanitize(markdown.render(text.to_s), tags: Rails::HTML5::SafeListSanitizer.allowed_tags + %w[table thead tbody tr th td])
  end
end
