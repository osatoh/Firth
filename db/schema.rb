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

ActiveRecord::Schema[8.1].define(version: 2026_09_22_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "articles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.string "guid", null: false
    t.datetime "published_at"
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["feed_id", "guid"], name: "index_articles_on_feed_id_and_guid", unique: true
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_fetched_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "url"], name: "index_feeds_on_user_id_and_url", unique: true
  end

  create_table "summaries", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.string "language", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "language"], name: "index_summaries_on_article_id_and_language", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.text "anthropic_api_key"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "google_uid", null: false
    t.string "name", null: false
    t.string "summary_language", default: "ja", null: false
    t.datetime "updated_at", null: false
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
  end

  add_foreign_key "articles", "feeds"
  add_foreign_key "feeds", "users"
  add_foreign_key "summaries", "articles"
end
