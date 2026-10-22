# frozen_string_literal: true

class AddUserToChats < ActiveRecord::Migration[8.1]
  # Chats before this had no owner. One chat per user replaces them.
  def up
    execute "DELETE FROM ruby_llm_tool_calls"
    execute "DELETE FROM ruby_llm_usages"
    execute "DELETE FROM messages"
    execute "DELETE FROM chats"
    add_reference :chats, :user, null: false, foreign_key: true, index: { unique: true }
  end

  def down
    remove_reference :chats, :user, foreign_key: true
  end
end
