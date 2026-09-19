class Avo::Resources::WaitlistEntry < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :business_link, as: :text
    field :email, as: :text
    field :phone, as: :text
  end
end
