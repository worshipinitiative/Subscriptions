class CreateSubscriptionsSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions_subscriptions do |t|
      t.references :ownerable, polymorphic: true
      t.datetime :next_bill_date
      t.integer :status,               default: 0
      t.integer :interval,               default: 0
      t.integer :amount_cents_next_period,               default: 0
      t.integer :amount_cents_base,               default: 0

      t.timestamps null: false
    end
    add_index :subscriptions_subscriptions, :next_bill_date
    add_index :subscriptions_subscriptions, :status
    add_index :subscriptions_subscriptions, :interval
  end
end
