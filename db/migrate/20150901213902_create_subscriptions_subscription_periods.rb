class CreateSubscriptionsSubscriptionPeriods < ActiveRecord::Migration
  def change
    create_table :subscriptions_subscription_periods do |t|
      t.references :subscription
      t.integer :amount_cents,               default: 0
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps null: false
    end
    add_index :subscriptions_subscription_periods, :start_at
    add_index :subscriptions_subscription_periods, :end_at
  end
end
