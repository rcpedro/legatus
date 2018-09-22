ActiveRecord::Schema.define do
  self.verbose = false

  create_table "merchant", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "products",  force: :cascade do |t|
    t.bigint  "merchant_id", null: false
    t.string  "name",        null: false
    t.string  "serial",      null: false
    t.integer "status",      null: false
    t.string  "description"
  end

  create_table "unit_prices", force: :cascade do |t|
    t.bigint   "product_id",     null: false
    t.decimal  "price",          null: false
    t.datetime "effective_date", null: false
  end

  create_table "comments",  force: :cascade do |t|
    t.bigint   "product_id",   null: false
    t.bigint   "user_id",      null: false
    t.string   "contents",     null: false
    t.datetime "commented_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.string   "code",       null: false
    t.datetime "ordered_at", null: false
    t.integer  "status",     null: false
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint  "order_id",   null: false
    t.bigint  "product_id", null: false
    t.integer "quantity",   null: false
    t.decimal "price",      null: false
  end

  create_table "discounts", force: :cascade do |t|
    t.bigint  "line_item_id",    null: false
    t.decimal "discount_amout",  null: false
    t.integer "strategy",        null: false
  end
end