class RenameExistingFieldsToAsSoldAndAddAsDeliveredToServices < ActiveRecord::Migration[8.0]
  def change
    # Rename existing fields to "as_sold"
    rename_column :services, :term_months, :term_months_as_sold
    rename_column :services, :billing_start_date, :billing_start_date_as_sold
    rename_column :services, :billing_end_date, :billing_end_date_as_sold
    rename_column :services, :rev_rec_start_date, :rev_rec_start_date_as_sold
    rename_column :services, :rev_rec_end_date, :rev_rec_end_date_as_sold

    # Add new "as_delivered" fields
    add_column :services, :term_months_as_delivered, :integer
    add_column :services, :billing_start_date_as_delivered, :date
    add_column :services, :billing_end_date_as_delivered, :date
    add_column :services, :rev_rec_start_date_as_delivered, :date
    add_column :services, :rev_rec_end_date_as_delivered, :date

    # Add indexes for the new date fields
    add_index :services, :billing_start_date_as_delivered
    add_index :services, :billing_end_date_as_delivered
    add_index :services, :rev_rec_start_date_as_delivered
    add_index :services, :rev_rec_end_date_as_delivered

    # Populate the as_delivered fields with the as_sold values for existing records
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE services
          SET term_months_as_delivered = term_months_as_sold,
              billing_start_date_as_delivered = billing_start_date_as_sold,
              billing_end_date_as_delivered = billing_end_date_as_sold,
              rev_rec_start_date_as_delivered = rev_rec_start_date_as_sold,
              rev_rec_end_date_as_delivered = rev_rec_end_date_as_sold
        SQL
      end
    end
  end
end
