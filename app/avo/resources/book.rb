# frozen_string_literal: true

class Avo::Resources::Book < Avo::BaseResource
  def fields
    field :id, as: :id
    field :title, as: :text
    field :slug, as: :text
    field :notion_database_id, as: :text
    field :chapters, as: :has_many
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def actions
    action Avo::Actions::SyncNotionChapters
  end
end
