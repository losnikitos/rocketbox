# frozen_string_literal: true

class CreateIncomingMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :incoming_messages do |t|
      t.string :channel, null: false
      t.string :external_id
      t.string :sender
      t.string :chat_id
      t.string :kind
      t.text :body
      t.json :payload, null: false
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :incoming_messages, [ :channel, :external_id ]
    add_index :incoming_messages, :created_at
  end
end
