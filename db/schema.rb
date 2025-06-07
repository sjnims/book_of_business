# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_07_181501) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.text "audited_changes"
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "customers", force: :cascade do |t|
    t.string "customer_id"
    t.string "name"
    t.string "email"
    t.string "phone"
    t.text "billing_address"
    t.string "technical_contact_name"
    t.string "technical_contact_email"
    t.string "technical_contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customers_on_customer_id", unique: true
    t.index ["email"], name: "index_customers_on_email"
    t.index ["name"], name: "index_customers_on_name"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_number"
    t.bigint "customer_id", null: false
    t.date "sold_date"
    t.decimal "tcv", precision: 15, scale: 2
    t.decimal "baseline_mrr", precision: 15, scale: 2
    t.decimal "gaap_mrr", precision: 15, scale: 2
    t.string "sales_rep"
    t.string "site"
    t.string "order_type"
    t.bigint "original_order_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["order_type"], name: "index_orders_on_order_type"
    t.index ["original_order_id"], name: "index_orders_on_original_order_id"
    t.index ["sales_rep"], name: "index_orders_on_sales_rep"
    t.index ["site"], name: "index_orders_on_site"
    t.index ["sold_date"], name: "index_orders_on_sold_date"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "service_type"
    t.string "service_name"
    t.integer "term_months"
    t.string "status"
    t.decimal "units", precision: 10, scale: 2
    t.decimal "unit_price", precision: 15, scale: 2
    t.decimal "nrcs", precision: 15, scale: 2
    t.decimal "annual_escalator", precision: 5, scale: 2
    t.decimal "mrr", precision: 15, scale: 2
    t.decimal "arr", precision: 15, scale: 2
    t.decimal "tcv", precision: 15, scale: 2
    t.string "site"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "billing_start_date"
    t.date "billing_end_date"
    t.date "rev_rec_start_date"
    t.date "rev_rec_end_date"
    t.index ["billing_end_date"], name: "index_services_on_billing_end_date"
    t.index ["billing_start_date"], name: "index_services_on_billing_start_date"
    t.index ["order_id"], name: "index_services_on_order_id"
    t.index ["rev_rec_end_date"], name: "index_services_on_rev_rec_end_date"
    t.index ["rev_rec_start_date"], name: "index_services_on_rev_rec_start_date"
    t.index ["service_type"], name: "index_services_on_service_type"
    t.index ["site"], name: "index_services_on_site"
    t.index ["status"], name: "index_services_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.integer "role", default: 0, null: false
    t.string "password_digest", null: false
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "orders", column: "original_order_id"
  add_foreign_key "services", "orders"
end
