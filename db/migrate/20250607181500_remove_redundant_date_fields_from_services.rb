class RemoveRedundantDateFieldsFromServices < ActiveRecord::Migration[8.0]
  def change
    # Remove redundant date fields
    remove_column :services, :installation_date, :date
    remove_column :services, :service_end_date, :date
  end
end