class Avo::Resources::Subscription < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :active, as: :boolean
    field :stripe_customer_id, as: :text
    field :stripe_subscription_id, as: :text
    field :status, as: :text
    field :current_period_end, as: :date_time
    field :user, as: :belongs_to
  end
end
