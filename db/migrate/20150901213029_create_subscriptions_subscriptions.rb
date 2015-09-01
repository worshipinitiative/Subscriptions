class CreateSubscriptionsSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions_subscriptions do |t|
      t.polymorphic :ownerable
      t.datetime :next_bill_date
      t.integer :status
      t.integer :interval
      t.integer :amount_cents_next_period
      t.integer :amount_cents_base

      t.timestamps null: false
    end
    add_index :subscriptions_subscriptions, :next_bill_date
    add_index :subscriptions_subscriptions, :status
    add_index :subscriptions_subscriptions, :interval
  end
end
