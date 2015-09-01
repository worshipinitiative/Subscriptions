class CreateSubscriptionsInvoices < ActiveRecord::Migration
  def change
    create_table :subscriptions_invoices do |t|
      t.references :ownerable, polymorphic: true
      t.datetime :next_payment_attempt_at
      t.string :stripe_charge_id
      t.integer :status,               default: 0
      t.datetime :paid_at
      t.string :slug, null: false
      t.integer :payment_status,               default: 0
      t.integer :failed_payment_attempt_count,               default: 0
      t.datetime :last_failed_payment_attempt_at
      t.text :last_failed_payment_error
      t.string :stripe_token
      t.string :stripe_customer_id
      t.string :stripe_card_last_four_digits
      t.string :stripe_card_expiration_month
      t.string :stripe_card_expiration_year
      t.string :stripe_card_type
      t.string :stripe_card_name_on_card
      t.integer :total_paid_cents,               default: 0
      t.integer :tax_paid_cents,                 default: 0
      t.integer :amount_refunded_cents

      t.timestamps null: false
    end
    add_index :subscriptions_invoices, :next_payment_attempt_at
    add_index :subscriptions_invoices, :stripe_charge_id
    add_index :subscriptions_invoices, :status
    add_index :subscriptions_invoices, :paid_at
    add_index :subscriptions_invoices, :slug
    add_index :subscriptions_invoices, :payment_status
    add_index :subscriptions_invoices, :failed_payment_attempt_count
    add_index :subscriptions_invoices, :stripe_token
    add_index :subscriptions_invoices, :stripe_customer_id
    add_index :subscriptions_invoices, :total_paid_cents
    add_index :subscriptions_invoices, :tax_paid_cents
  end
end
