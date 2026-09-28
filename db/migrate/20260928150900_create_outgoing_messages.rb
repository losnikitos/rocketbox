# frozen_string_literal: true

class CreateOutgoingMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :outgoing_messages do |t|
      t.string :channel, null: false
      t.string :external_id
      t.string :recipient
      t.string :kind
      t.text :body
      t.json :payload, null: false
      t.text :error
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :outgoing_messages, [ :channel, :external_id ]
    add_index :outgoing_messages, :created_at
  end
end
