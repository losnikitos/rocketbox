# frozen_string_literal: true

# macOS Pango defaults to CoreText, which ignores Vips::Image.text(fontfile:); Linux already uses fontconfig.
ENV["PANGOCAIRO_BACKEND"] ||= "fc"

class Workflow
  # Fixed text laid over each image, placed on a 9-cell grid (position "top_left" … "bottom_right") inside the format's safe area.
  class TextOverlay
    LABEL = "Text"
    ICON = "chat-bubble-bottom-center-text"
    SCHEME = %i[text].freeze
    DEFAULTS = { "body" => "", "position" => "bottom_center", "size" => "L", "style" => "shade" }.freeze
    # Font size as a fraction of canvas width.
    SIZES = { "S" => 0.05, "M" => 0.065, "L" => 0.08 }.freeze
    FONT = Rails.root.join("app/assets/fonts/Manrope.ttf").to_s

    def self.call(inputs:, params:, run:)
      inputs.map { { io: StringIO.new(render(it.download, params, run.workflow_class.format)), filename: "text.jpg", content_type: "image/jpeg" } }
    end

    # Returns JPEG bytes.
    def self.render(bytes, params, format)
      params = DEFAULTS.merge(params.compact_blank)
      vertical, horizontal = params["position"].to_s.split("_")
      vertical = "bottom" unless vertical.in?(%w[top middle bottom])
      horizontal = "center" unless horizontal.in?(%w[left center right])

      image = MediaCanvas.cover(bytes, format)
      top, right, bottom, left = MediaCanvas.insets(format)
      image = image.composite2(scrim(image.width, image.height, vertical), :over) if params["style"] == "shade" && vertical != "middle"

      font_px = (image.width * SIZES.fetch(params["size"], SIZES["L"])).round
      text = text_image(params["body"], "white", font_px, image.width - left - right, horizontal)
      x = { "left" => left, "center" => (image.width - text.width) / 2, "right" => image.width - right - text.width }.fetch(horizontal)
      y = { "top" => top, "middle" => (image.height - text.height) / 2, "bottom" => image.height - bottom - text.height }.fetch(vertical)

      pad = (font_px * 0.3).round
      shadow = text_image(params["body"], "black", font_px, image.width - left - right, horizontal)
        .embed(pad, pad, text.width + pad * 2, text.height + pad * 2).gaussblur(font_px * 0.1) * [ 1, 1, 1, 0.6 ]
      image = image.composite([ shadow.cast(:uchar), text ], :over, x: [ x - pad, x ], y: [ y - pad + font_px / 20, y ])
      MediaCanvas.jpeg(image.extract_band(0, n: 3))
    end

    def self.text_image(body, color, font_px, width, horizontal)
      Vips::Image.text(%(<span foreground="#{color}">#{ERB::Util.html_escape(body)}</span>),
        fontfile: FONT, font: "Manrope ExtraBold #{font_px}", width:, align: { "left" => :low, "center" => :centre, "right" => :high }.fetch(horizontal),
        rgba: true, dpi: 72)
    end

    # Black gradient behind top or bottom text: transparent at 45% of the height, 70% black at the edge.
    def self.scrim(width, height, vertical)
      t = Vips::Image.xyz(width, height)[1].cast(:float) / height
      t = t * -1 + 1 if vertical == "top"
      t = (t - 0.45) / 0.55
      t = (t < 0).ifthenelse(0, t)
      alpha = (t * 180).cast(:uchar)
      Vips::Image.black(width, height, bands: 3).cast(:uchar).bandjoin(alpha).copy(interpretation: :srgb)
    end
  end
end
