# frozen_string_literal: true

# A scene to shoot (e.g. "Empty Chair"): its `body` is appended to a recipe's body when a recipe post uses it.
# Recipes take a shot `group`; the concrete shot is picked per post.
class Shot < ApplicationRecord
  # Posts outlive their shot.
  has_many :smm_posts, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, :group, presence: true

  # Seed order follows a working day.
  scope :ordered, -> { order(:id) }

  def self.groups = distinct.order(:group).pluck(:group)
end
