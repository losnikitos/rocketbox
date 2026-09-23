# frozen_string_literal: true

class Avo::Resources::LibraryMedia < Avo::BaseResource
  self.title = :id

  def fields
    field :id, as: :id
    field :kind, as: :text
    field :telegram_file_id, as: :text
    field :telegram_file_unique_id, as: :text
    field :whatsapp_media_id, as: :text
    field :whatsapp_from, as: :text
    field :chat_id, as: :number
    field :from_id, as: :number
    field :user, as: :belongs_to
    field :file, as: :file
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
