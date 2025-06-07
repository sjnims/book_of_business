class AddBillingAndRevRecDatesToServices < ActiveRecord::Migration[8.0]
  def change
    # Add billing date fields
    add_column :services, :billing_start_date, :date
    add_column :services, :billing_end_date, :date
    
    # Add revenue recognition date fields
    add_column :services, :rev_rec_start_date, :date
    add_column :services, :rev_rec_end_date, :date
    
    # Add indexes for performance when querying by these dates
    add_index :services, :billing_start_date
    add_index :services, :billing_end_date
    add_index :services, :rev_rec_start_date
    add_index :services, :rev_rec_end_date
    
    # Rename existing start_date and end_date to be more specific
    # These will represent the service installation/lifecycle dates
    rename_column :services, :start_date, :installation_date
    rename_column :services, :end_date, :service_end_date
  end
end