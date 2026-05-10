class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :email, as: :text
    field :role,
      as: :select,
      options: {
        "User" => "user",
        "Admin" => "admin"
      }
    field :verified, as: :boolean
    field :sessions, as: :has_many
    field :subscription, as: :has_one
  end
end
