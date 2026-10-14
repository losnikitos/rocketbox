# frozen_string_literal: true

# Inbox media no other subfolder fits gets sorted into Inbox / Misc.
class CreateInboxMisc < ActiveRecord::Migration[8.1]
  def up
    Folder.inbox.children.find_or_create_by!(slug: "misc") { it.name = "Misc" }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
