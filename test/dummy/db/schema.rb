# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150901215919) do

  create_table "subscriptions_invoice_items_invoices", force: :cascade do |t|
    t.integer  "invoice_id"
    t.integer  "invoice_itemable_id"
    t.string   "invoice_itemable_type"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "subscriptions_invoices", force: :cascade do |t|
    t.integer  "ownerable_id"
    t.string   "ownerable_type"
    t.datetime "next_payment_attempt_at"
    t.string   "stripe_charge_id"
    t.integer  "status",                         default: 0
    t.datetime "paid_at"
    t.string   "slug",                                       null: false
    t.integer  "payment_status",                 default: 0
    t.integer  "failed_payment_attempt_count",   default: 0
    t.datetime "last_failed_payment_attempt_at"
    t.text     "last_failed_payment_error"
    t.string   "stripe_token"
    t.string   "stripe_customer_id"
    t.string   "stripe_card_last_four_digits"
    t.string   "stripe_card_expiration_month"
    t.string   "stripe_card_expiration_year"
    t.string   "stripe_card_type"
    t.string   "stripe_card_name_on_card"
    t.integer  "total_paid_cents",               default: 0
    t.integer  "tax_paid_cents",                 default: 0
    t.integer  "amount_refunded_cents"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "subscriptions_invoices", ["failed_payment_attempt_count"], name: "index_subscriptions_invoices_on_failed_payment_attempt_count"
  add_index "subscriptions_invoices", ["next_payment_attempt_at"], name: "index_subscriptions_invoices_on_next_payment_attempt_at"
  add_index "subscriptions_invoices", ["paid_at"], name: "index_subscriptions_invoices_on_paid_at"
  add_index "subscriptions_invoices", ["payment_status"], name: "index_subscriptions_invoices_on_payment_status"
  add_index "subscriptions_invoices", ["slug"], name: "index_subscriptions_invoices_on_slug"
  add_index "subscriptions_invoices", ["status"], name: "index_subscriptions_invoices_on_status"
  add_index "subscriptions_invoices", ["stripe_charge_id"], name: "index_subscriptions_invoices_on_stripe_charge_id"
  add_index "subscriptions_invoices", ["stripe_customer_id"], name: "index_subscriptions_invoices_on_stripe_customer_id"
  add_index "subscriptions_invoices", ["stripe_token"], name: "index_subscriptions_invoices_on_stripe_token"
  add_index "subscriptions_invoices", ["tax_paid_cents"], name: "index_subscriptions_invoices_on_tax_paid_cents"
  add_index "subscriptions_invoices", ["total_paid_cents"], name: "index_subscriptions_invoices_on_total_paid_cents"

  create_table "subscriptions_subscription_periods", force: :cascade do |t|
    t.integer  "subscription_id"
    t.integer  "amount_cents",    default: 0
    t.datetime "start_at"
    t.datetime "end_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "subscriptions_subscription_periods", ["end_at"], name: "index_subscriptions_subscription_periods_on_end_at"
  add_index "subscriptions_subscription_periods", ["start_at"], name: "index_subscriptions_subscription_periods_on_start_at"

  create_table "subscriptions_subscription_template_groups", force: :cascade do |t|
    t.string   "name"
    t.boolean  "visible"
    t.integer  "position"
    t.boolean  "popular"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "subscriptions_subscription_template_groups", ["name"], name: "index_subscriptions_subscription_template_groups_on_name"
  add_index "subscriptions_subscription_template_groups", ["position"], name: "index_subscriptions_subscription_template_groups_on_position"
  add_index "subscriptions_subscription_template_groups", ["visible"], name: "index_subscriptions_subscription_template_groups_on_visible"

  create_table "subscriptions_subscription_templates", force: :cascade do |t|
    t.string   "name"
    t.integer  "amount_cents"
    t.integer  "interval"
    t.string   "slug"
    t.boolean  "visible"
    t.integer  "subscription_template_group_id"
    t.integer  "position"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "subscriptions_subscription_templates", ["amount_cents"], name: "index_subscriptions_subscription_templates_on_amount_cents"
  add_index "subscriptions_subscription_templates", ["interval"], name: "index_subscriptions_subscription_templates_on_interval"
  add_index "subscriptions_subscription_templates", ["name"], name: "index_subscriptions_subscription_templates_on_name"
  add_index "subscriptions_subscription_templates", ["position"], name: "index_subscriptions_subscription_templates_on_position"
  add_index "subscriptions_subscription_templates", ["slug"], name: "index_subscriptions_subscription_templates_on_slug"
  add_index "subscriptions_subscription_templates", ["subscription_template_group_id"], name: "index_subscriptions_subscription_template_group_id"
  add_index "subscriptions_subscription_templates", ["visible"], name: "index_subscriptions_subscription_templates_on_visible"

  create_table "subscriptions_subscriptions", force: :cascade do |t|
    t.integer  "ownerable_id"
    t.string   "ownerable_type"
    t.datetime "next_bill_date"
    t.integer  "status",                   default: 0
    t.integer  "interval",                 default: 0
    t.integer  "amount_cents_next_period", default: 0
    t.integer  "amount_cents_base",        default: 0
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  add_index "subscriptions_subscriptions", ["interval"], name: "index_subscriptions_subscriptions_on_interval"
  add_index "subscriptions_subscriptions", ["next_bill_date"], name: "index_subscriptions_subscriptions_on_next_bill_date"
  add_index "subscriptions_subscriptions", ["status"], name: "index_subscriptions_subscriptions_on_status"

end
