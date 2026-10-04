# frozen_string_literal: true

# An SMM post factory defined in code: makes one draft post at a time for an account.
# Each account's switch and choices (photo type, layer) live in a FeatureSetting.
class Feature
  attr_reader :slug, :name, :description, :format, :media_type, :layer, :layer_values

  def initialize(slug:, name:, description:, format:, media_type:, layer:, layer_values:)
    @slug, @name, @description, @format = slug, name, description, format
    @media_type, @layer, @layer_values = media_type, layer, layer_values
  end

  ALL = [
    new(slug: "fully-booked", name: "Fully booked", format: "story",
      description: "A Story with a working photo and the Fully booked layer for tomorrow.",
      media_type: "working", layer: "fully-booked", layer_values: -> { { date: Date.tomorrow.iso8601 } })
  ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def to_param = slug

  def setting_for(user)
    user.feature_settings.find_or_initialize_by(feature_slug: slug) do
      it.media_type = MediaType.find_by(slug: media_type)
      it.layer_slug = layer
    end
  end

  # Raises ActiveRecord::RecordNotFound when the photobank has no photo of the setting's type.
  def create_post!(user)
    setting = setting_for(user)
    photo = setting.media_type && user.library_media.photobank.where(media_type: setting.media_type).with_attached_file.select(&:story_image?).sample
    raise ActiveRecord::RecordNotFound, "No #{setting.media_type&.name || "matching"} photo in the photobank." unless photo

    post = user.smm_posts.new(format:, feature_slug: slug, status: "generating")
    post.smm_post_media_items.build(library_media: photo, position: 0)
    post.save!
    GenerateSmmPostJob.perform_later(post.id)
    post
  end

  # PNG bytes: the setting's layer over the post's photo, cropped to the layer's size.
  def render(post)
    layer = setting_for(post.user).layer
    photo = post.library_media.first.file.variant(resize_to_fill: layer.size, format: :jpeg).processed
    html = Current.set(account: post.user) do
      ApplicationController.render("accounts/layers/canvas", layout: false,
        assigns: { layer:, values: layer.values(layer_values.call) },
        locals: { background: "data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}" })
    end
    Layer.screenshot(html, size: layer.size)
  end
end
