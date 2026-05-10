# frozen_string_literal: true

class Avo::Resources::Document < Avo::BaseResource
  def fields
    field :id, as: :id
    field :name, as: :text, help: "Short label (used for the slug and footer link text)."
    field :slug, as: :text, readonly: true
    field :title, as: :text, help: "Page heading shown on the public document."
    field :body, as: :textarea, help: "Markdown body."
    field :published, as: :boolean
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
