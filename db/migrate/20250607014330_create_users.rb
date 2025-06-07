class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.integer :role, default: 0, null: false
      t.string :password_digest, null: false
      t.string :password_reset_token
      t.datetime :password_reset_sent_at

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :password_reset_token, unique: true
  end
end
