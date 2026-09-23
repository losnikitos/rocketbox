# frozen_string_literal: true

class Avo::Resources::IncomingMessage < Avo::BaseResource
  self.title = :id

  def fields
    field :id, as: :id
    field :channel, as: :text
    field :external_id, as: :text
    field :sender, as: :text
    field :chat_id, as: :text
    field :kind, as: :text
    field :body, as: :textarea
    field :payload, as: :code, language: "json"
    field :user, as: :belongs_to
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
end
