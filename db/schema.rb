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

ActiveRecord::Schema[8.1].define(version: 2026_05_11_004417) do
  create_table "books", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "notion_database_id"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["notion_database_id"], name: "index_books_on_notion_database_id", unique: true
    t.index ["slug"], name: "index_books_on_slug", unique: true
  end

  create_table "chapters", force: :cascade do |t|
    t.integer "book_id", null: false
    t.datetime "created_at", null: false
    t.boolean "free", default: false, null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "position"], name: "index_chapters_on_book_id_and_position", unique: true
    t.index ["book_id"], name: "index_chapters_on_book_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "published", default: false, null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_documents_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.string "status"
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "chapters", "books"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "users"
end
