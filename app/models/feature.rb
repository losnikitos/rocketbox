# frozen_string_literal: true

# An SMM post factory defined in code: makes one draft post at a time for an account.
# Each account's switch and choices (recipe, layer) live in a FeatureSetting.
class Feature
  attr_reader :slug, :name, :description, :format, :layer, :layer_values

  def initialize(slug:, name:, description:, format:, layer:, layer_values:)
    @slug, @name, @description, @format = slug, name, description, format
    @layer, @layer_values = layer, layer_values
  end

  ALL = [
    new(slug: "fully-booked", name: "Fully booked", format: "story",
      description: "A Story with a Ready photo and the Fully booked layer for tomorrow.",
      layer: "fully-booked", layer_values: -> { { date: Date.tomorrow.iso8601 } })
  ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def to_param = slug

  def setting_for(user)
    user.feature_settings.find_or_initialize_by(feature_slug: slug) { it.layer_slug = layer }
  end

  # Raises ActiveRecord::RecordNotFound when Ready has no photo from the setting's recipe.
  def create_post!(user)
    setting = setting_for(user)
    photo = setting.recipe && user.library_media.ready.joins(:recipe_run).where(recipe_runs: { recipe_id: setting.recipe_id })
      .with_attached_file.select(&:story_image?).sample
    raise ActiveRecord::RecordNotFound, "No #{setting.recipe&.name || "matching"} photo in Ready." unless photo

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
