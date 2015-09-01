class CreateSubscriptionsSubscriptionTemplateGroups < ActiveRecord::Migration
  def change
    create_table :subscriptions_subscription_template_groups do |t|
      t.string :name
      t.boolean :visible
      t.integer :position
      t.boolean :popular

      t.timestamps null: false
    end
    add_index :subscriptions_subscription_template_groups, :name
    add_index :subscriptions_subscription_template_groups, :visible
    add_index :subscriptions_subscription_template_groups, :position
  end
end
