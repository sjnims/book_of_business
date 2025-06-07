class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :customer_id
      t.string :name
      t.string :email
      t.string :phone
      t.text :billing_address
      t.string :technical_contact_name
      t.string :technical_contact_email
      t.string :technical_contact_phone

      t.timestamps
    end
    add_index :customers, :customer_id, unique: true
    add_index :customers, :email
    add_index :customers, :name
  end
end
