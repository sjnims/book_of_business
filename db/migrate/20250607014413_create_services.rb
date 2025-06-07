class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services do |t|
      t.references :order, null: false, foreign_key: true
      t.string :service_type
      t.string :service_name
      t.integer :term_months
      t.string :status
      t.date :start_date
      t.date :end_date
      t.decimal :units, precision: 10, scale: 2
      t.decimal :unit_price, precision: 15, scale: 2
      t.decimal :nrcs, precision: 15, scale: 2
      t.decimal :annual_escalator, precision: 5, scale: 2
      t.decimal :mrr, precision: 15, scale: 2
      t.decimal :arr, precision: 15, scale: 2
      t.decimal :tcv, precision: 15, scale: 2
      t.string :site

      t.timestamps
    end
    
    add_index :services, :end_date
    add_index :services, :service_type
    add_index :services, :site
    add_index :services, :start_date
    add_index :services, :status
  end
end
