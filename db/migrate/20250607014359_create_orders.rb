class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :order_number
      t.references :customer, null: false, foreign_key: true
      t.date :sold_date
      t.decimal :tcv, precision: 15, scale: 2
      t.decimal :baseline_mrr, precision: 15, scale: 2
      t.decimal :gaap_mrr, precision: 15, scale: 2
      t.string :sales_rep
      t.string :site
      t.string :order_type
      t.bigint :original_order_id
      t.text :notes

      t.timestamps
    end
    add_index :orders, :order_number, unique: true
    add_index :orders, :order_type
    add_index :orders, :original_order_id
    add_index :orders, :sales_rep
    add_index :orders, :site
    add_index :orders, :sold_date
    
    add_foreign_key :orders, :orders, column: :original_order_id
  end
end
