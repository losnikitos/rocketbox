# frozen_string_literal: true

class AddSubscriptionToUsersAndFreeToChapters < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :subscribed, :boolean, default: false, null: false
    add_column :chapters, :free, :boolean, default: false, null: false

    book = Book.find_by(slug: "coffeeshop")
    book&.chapters&.find_by(position: 1)&.update_column(:free, true)
  end

  def down
    remove_column :chapters, :free
    remove_column :users, :subscribed
  end
end
