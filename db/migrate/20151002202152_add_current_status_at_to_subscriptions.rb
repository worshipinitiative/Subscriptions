class AddCurrentStatusAtToSubscriptions < ActiveRecord::Migration
  def change
    add_column :subscriptions_subscriptions, :current_status_at, :datetime
    add_index :subscriptions_subscriptions, :current_status_at
  end
end
