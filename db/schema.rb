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

ActiveRecord::Schema[7.0].define(version: 2022_04_21_181843) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "bird_families", force: :cascade do |t|
    t.string "scientific_name"
    t.string "common_names", array: true
    t.integer "species_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bird_species", force: :cascade do |t|
    t.string "external_id", limit: 12, null: false
    t.string "scientific_name", null: false
    t.string "common_names", null: false, array: true
    t.jsonb "distribution"
    t.bigint "bird_family_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bird_family_id"], name: "index_bird_species_on_bird_family_id"
  end

  create_table "spatial_ref_sys", primary_key: "srid", id: :integer, default: nil, force: :cascade do |t|
    t.string "auth_name", limit: 256
    t.integer "auth_srid"
    t.string "srtext", limit: 2048
    t.string "proj4text", limit: 2048
    t.check_constraint "srid > 0 AND srid <= 998999", name: "spatial_ref_sys_srid_check"
  end

  add_foreign_key "bird_species", "bird_families"
end
