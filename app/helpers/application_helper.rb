module ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  def tw_label_classes
    "mb-1 block text-sm font-medium text-ink-700"
  end

  def tw_input_classes
    "mt-1 block w-full rounded-[10px] border border-ink-900/15 bg-white px-3 py-2 text-ink-900 shadow-none placeholder:text-ink-400 focus:border-rocket focus:outline-none focus:ring-2 focus:ring-rocket/30 sm:text-sm"
  end

  def tw_btn_primary_classes
    "rb-btn-primary w-full"
  end

  def tw_btn_secondary_classes
    "rb-btn-ghost-on-light w-full"
  end

  def tw_alert_success_classes
    "mb-4 rounded-[10px] border border-signal-green/40 bg-paper-200 px-3 py-2 text-sm text-ink-900"
  end

  def tw_alert_error_classes
    "mb-4 rounded-[10px] border border-signal-red/35 bg-paper-200 px-3 py-2 text-sm text-ink-900"
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
    sanitize(markdown.render(text.to_s))
  end
end
