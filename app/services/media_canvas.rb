# frozen_string_literal: true

# Output canvas per post format: pixel size, Instagram keep-clear insets, cover-crop, and JPEG encoding (libvips).
module MediaCanvas
  SIZES = { "story" => [ 1080, 1920 ], "reel" => [ 1080, 1920 ], "post" => [ 1080, 1350 ] }.freeze
  # Fractions of the canvas [top, right, bottom, left] hidden by Instagram UI chrome (story/reel from tadaaa SAFE_AREA_INSETS).
  SAFE_AREA = { "story" => [ 0.084, 0.06, 0.2, 0.06 ], "reel" => [ 0.06, 0.09, 0.34, 0.09 ], "post" => [ 0.06, 0.06, 0.06, 0.06 ] }.freeze

  extend self

  def size(format)
    SIZES.fetch(format.to_s, SIZES["story"])
  end

  # [top, right, bottom, left] in pixels.
  def insets(format)
    width, height = size(format)
    top, right, bottom, left = SAFE_AREA.fetch(format.to_s, SAFE_AREA["story"])
    [ top * height, right * width, bottom * height, left * width ].map(&:round)
  end

  # Auto-rotated, centre-cropped to fill the format, sRGB without alpha.
  def cover(bytes, format)
    width, height = size(format)
    image = Vips::Image.thumbnail_buffer(bytes, width, height:, crop: :centre)
    image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
    image.colourspace(:srgb)
  end

  def jpeg(image)
    image.jpegsave_buffer(Q: 90)
  end

  # The blob itself when it's already a JPEG of the format's size, otherwise a cover-cropped JPEG attachable.
  def fit(blob, format)
    bytes = blob.download
    header = Vips::Image.new_from_buffer(bytes, "")
    return blob if blob.content_type == "image/jpeg" && [ header.width, header.height ] == size(format)

    { io: StringIO.new(jpeg(cover(bytes, format))), filename: "slide.jpg", content_type: "image/jpeg" }
  end
end
