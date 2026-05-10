# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def up
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    User.reset_column_information
    User.find_each do |user|
      Subscription.create!(user_id: user.id, active: user.subscribed)
    end

    remove_column :users, :subscribed
  end

  def down
    add_column :users, :subscribed, :boolean, default: false, null: false

    User.reset_column_information
    Subscription.find_each do |sub|
      User.where(id: sub.user_id).update_all(subscribed: sub.active)
    end

    drop_table :subscriptions
  end
end
