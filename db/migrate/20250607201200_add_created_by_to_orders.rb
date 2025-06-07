class AddCreatedByToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :created_by, null: true, foreign_key: { to_table: :users }
    
    # Update existing orders to have the first admin user as created_by
    reversible do |dir|
      dir.up do
        admin_user = execute("SELECT id FROM users WHERE role = 0 LIMIT 1").first
        if admin_user
          execute("UPDATE orders SET created_by_id = #{admin_user['id']} WHERE created_by_id IS NULL")
        end
      end
    end
    
    # Now make it required
    change_column_null :orders, :created_by_id, false
  end
end
