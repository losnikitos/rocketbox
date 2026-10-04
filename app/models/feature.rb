# frozen_string_literal: true

# An SMM post factory defined in code: makes one draft post at a time for an account.
# Each account's switch and choices (recipe, layer) live in a FeatureSetting.
class Feature
  attr_reader :slug, :name, :description, :format, :layer, :layer_values, :fixed_layer

  def initialize(slug:, name:, description:, format:, layer:, layer_values:, fixed_layer: false)
    @slug, @name, @description, @format = slug, name, description, format
    @layer, @layer_values, @fixed_layer = layer, layer_values, fixed_layer
  end

  ALL = [
    new(slug: "fully-booked", name: "Fully booked", format: "story",
      description: "A Story with a Ready photo and the Fully booked layer for tomorrow.",
      layer: "fully-booked", layer_values: ->(_user) { { date: Date.tomorrow.iso8601 } }),
    new(slug: "reviews", name: "Reviews", format: "story",
      description: "A Story with a Ready photo and a random 5-star review on the Review layer.",
      layer: "review", fixed_layer: true, layer_values: ->(user) { review_values(user) })
  ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  # ponytail: random pick can repeat a review; track posted reviews if that starts to show.
  def self.review_values(user)
    review = user.reviews.active.where(rating: 5).where.not(body: [ nil, "" ]).order(Arel.sql("RANDOM()")).first
    raise ActiveRecord::RecordNotFound, "No 5-star review with text to post." unless review

    avatar = review.avatar.variant(resize_to_fill: [ 256, 256 ], format: :jpeg).processed if review.avatar.attached?
    { text: review.body.truncate(240, separator: " "), name: review.customer_name,
      photo: ("data:image/jpeg;base64,#{Base64.strict_encode64(avatar.download)}" if avatar) }
  end

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

  # PNG bytes: the layer over the post's photo, cropped to the layer's size.
  def render(post)
    layer = Layer.find(fixed_layer ? self.layer : setting_for(post.user).layer_slug)
    photo = post.library_media.first.file.variant(resize_to_fill: layer.size, format: :jpeg).processed
    html = Current.set(account: post.user) do
      ApplicationController.render("accounts/layers/canvas", layout: false,
        assigns: { layer:, values: layer.values(layer_values.call(post.user)) },
        locals: { background: "data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}" })
    end
    Layer.screenshot(html, size: layer.size)
  end
end
