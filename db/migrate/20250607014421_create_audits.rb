class CreateAudits < ActiveRecord::Migration[8.0]
  def change
    create_table :audits do |t|
      t.integer :auditable_id
      t.string :auditable_type
      t.integer :associated_id
      t.string :associated_type
      t.integer :user_id
      t.string :user_type
      t.string :username
      t.string :action
      t.text :audited_changes
      t.integer :version, default: 0
      t.string :comment
      t.string :remote_address
      t.string :request_uuid
      t.datetime :created_at
    end

    add_index :audits, [:associated_type, :associated_id], name: "associated_index"
    add_index :audits, [:auditable_type, :auditable_id, :version], name: "auditable_index"
    add_index :audits, :created_at
    add_index :audits, :request_uuid
    add_index :audits, [:user_id, :user_type], name: "user_index"
  end
end
