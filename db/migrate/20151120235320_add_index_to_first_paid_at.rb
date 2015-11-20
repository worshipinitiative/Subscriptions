class AddIndexToFirstPaidAt < ActiveRecord::Migration
  disable_ddl_transaction!
  def change
    unless index_exists? :subscriptions_subscriptions, :first_paid_at
      add_index :subscriptions_subscriptions, :first_paid_at
    end
  end
end
