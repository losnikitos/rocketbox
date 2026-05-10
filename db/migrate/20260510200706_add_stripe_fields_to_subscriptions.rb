class AddStripeFieldsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :stripe_customer_id, :string
    add_column :subscriptions, :stripe_subscription_id, :string
    add_column :subscriptions, :status, :string
    add_column :subscriptions, :current_period_end, :datetime

    add_index :subscriptions, :stripe_customer_id
    add_index :subscriptions, :stripe_subscription_id, unique: true
  end
end
