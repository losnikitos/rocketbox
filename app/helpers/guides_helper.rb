# frozen_string_literal: true

module GuidesHelper
  COMPARE_BLOCK = /:::compare\n(.*?):::/m

  def render_guide_markdown(text)
    safe_join(text.to_s.split(COMPARE_BLOCK).each_slice(2).flat_map { |md, block|
      [ render_markdown(md), (render_compare_block(block) if block) ]
    }.compact)
  end

  private

  def render_compare_block(body)
    attrs = body.lines.filter_map { |line|
      key, value = line.strip.split(":", 2)
      [ key, value.strip ] if key.present? && value
    }.to_h
    render partial: "guides/compare", locals: {
      do_src: attrs["do"],
      dont_src: attrs["dont"],
      do_label: attrs["do_label"].presence || "Do",
      dont_label: attrs["dont_label"].presence || "Don't"
    }
  end
end
