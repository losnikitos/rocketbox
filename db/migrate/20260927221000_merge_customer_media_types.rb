class MergeCustomerMediaTypes < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE library_media SET media_type = 'customer' WHERE media_type IN ('customer_before', 'customer_after')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
