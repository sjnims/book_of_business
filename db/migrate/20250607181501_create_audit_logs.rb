class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :audited_changes
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata

      t.timestamps
    end
    
    add_index :audit_logs, :action
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :created_at
  end
end
