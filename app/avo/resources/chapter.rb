# frozen_string_literal: true

class Avo::Resources::Chapter < Avo::BaseResource
  def fields
    field :id, as: :id
    field :book, as: :belongs_to
    field :position, as: :number
    field :title, as: :text
    field :free, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
