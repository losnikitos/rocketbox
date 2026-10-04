# frozen_string_literal: true

# An SMM post factory defined in code: makes one draft post at a time for an account.
# Each account's switch and choices (recipe, layer) live in a FeatureSetting.
class Feature
  attr_reader :slug, :name, :description, :schedule, :format, :layer, :layer_values, :fixed_layer, :fixed_recipe_id

  def initialize(slug:, name:, description:, schedule:, format:, layer:, layer_values:, fixed_layer: false, fixed_recipe_id: nil)
    @slug, @name, @description, @schedule, @format = slug, name, description, schedule, format
    @layer, @layer_values, @fixed_layer, @fixed_recipe_id = layer, layer_values, fixed_layer, fixed_recipe_id
  end

  ALL = [
    new(slug: "fully-booked", name: "Fully booked", format: "story", schedule: "Every day at 6pm",
      description: "A Story with a Ready photo and the Fully booked layer for tomorrow.",
      layer: "fully-booked", layer_values: ->(_post) { { date: Date.tomorrow.iso8601 } }),
    new(slug: "reviews", name: "Reviews", format: "story", schedule: "3 times a week, Mon/Wed/Fri at 10am",
      description: "A Story with a Ready photo and a 5-star review on the Review layer.",
      layer: "review", fixed_layer: true, layer_values: ->(post) { review_values(post.review) }),
    new(slug: "daily", name: "Daily", format: "story", schedule: "5 times a day, Mon–Fri",
      description: "A Story with a Будни photo and the Daily layer.",
      layer: "daily", fixed_layer: true, fixed_recipe_id: 8, layer_values: ->(_post) { {} })
  ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def self.review_values(review)
    avatar = review.avatar.variant(resize_to_fill: [ 256, 256 ], format: :jpeg).processed if review.avatar.attached?
    { text: review.body.truncate(240, separator: " "), name: review.customer_name,
      photo: ("data:image/jpeg;base64,#{Base64.strict_encode64(avatar.download)}" if avatar) }
  end

  def to_param = slug

  def reviews? = layer == "review"

  def setting_for(user)
    user.feature_settings.find_or_initialize_by(feature_slug: slug) { it.layer_slug = layer }
  end

  def posts(user) = user.smm_posts.where(feature_slug: slug)

  def recipe(user) = fixed_recipe_id ? Recipe.find_by(id: fixed_recipe_id) : setting_for(user).recipe

  # Ready media from the feature's recipe.
  def ready_photos(user)
    recipe = recipe(user)
    return LibraryMedia.none unless recipe

    user.library_media.ready.joins(:recipe_run).where(recipe_runs: { recipe_id: recipe.id })
  end

  def photo_backlog(user)
    ready_photos(user).where.not(id: SmmPostMediaItem.where(smm_post: posts(user)).select(:library_media_id))
  end

  def five_star_reviews(user) = user.reviews.active.where(rating: 5).where.not(body: [ nil, "" ])

  def review_backlog(user)
    five_star_reviews(user).where.not(id: posts(user).where.not(review_id: nil).select(:review_id))
  end

  # Picks an unused photo (and review) unless given. Raises ActiveRecord::RecordNotFound when the backlog is empty.
  def create_post!(user, photo: nil, review: nil)
    photo ||= photo_backlog(user).with_attached_file.select(&:story_image?).sample
    raise ActiveRecord::RecordNotFound, "No #{recipe(user)&.name || "matching"} photo in Ready." unless photo

    if reviews?
      review ||= review_backlog(user).order(Arel.sql("RANDOM()")).first
      raise ActiveRecord::RecordNotFound, "No 5-star review with text to post." unless review
    end

    post = user.smm_posts.new(format:, feature_slug: slug, review:, status: "generating")
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
        assigns: { layer:, values: layer.values(layer_values.call(post)) },
        locals: { background: "data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}" })
    end
    Layer.screenshot(html, size: layer.size)
  end
end
