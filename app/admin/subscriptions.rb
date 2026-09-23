ActiveAdmin.register Subscription do
  permit_params :user_id, :active, :stripe_customer_id, :stripe_subscription_id, :status, :current_period_end
end
