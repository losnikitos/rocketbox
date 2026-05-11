module ApplicationHelper
  include ActionView::Helpers::SanitizeHelper

  def tw_label_classes
    "mb-1 block text-sm font-medium text-slate-700"
  end

  def tw_input_classes
    "mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 sm:text-sm"
  end

  def tw_btn_primary_classes
    "inline-flex w-full cursor-pointer items-center justify-center rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
  end

  def tw_btn_secondary_classes
    "inline-flex cursor-pointer items-center justify-center rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-800 shadow-sm transition hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-slate-400 focus:ring-offset-2"
  end

  def tw_alert_success_classes
    "mb-4 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
  end

  def tw_alert_error_classes
    "mb-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
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
