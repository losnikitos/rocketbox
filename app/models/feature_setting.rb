# frozen_string_literal: true

# An account's switch and choices for one Feature.
class FeatureSetting < ApplicationRecord
  belongs_to :user
  # The recipe whose Ready photos the feature uses; nil until the owner picks one.
  belongs_to :recipe, optional: true

  validates :feature_slug, inclusion: { in: Feature::ALL.map(&:slug) }
  validates :layer_slug, inclusion: { in: Layer::ALL.map(&:slug) }

  def layer = Layer.find(layer_slug)
end
