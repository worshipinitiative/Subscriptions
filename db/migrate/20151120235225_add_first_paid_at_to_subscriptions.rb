class AddFirstPaidAtToSubscriptions < ActiveRecord::Migration
  def change
    unless column_exists? :subscriptions_subscriptions, :first_paid_at
      # Since this existed on an install of the engine but wasn't in the engine itself we need to check for the existance of this column.
      add_column :subscriptions_subscriptions, :first_paid_at, :datetime
    end
  end
end
