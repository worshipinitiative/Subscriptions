class CreateSubscriptionsSubscriptionTemplates < ActiveRecord::Migration
  def change
    create_table :subscriptions_subscription_templates do |t|
      t.string :name
      t.integer :amount_cents
      t.integer :interval
      t.string :slug
      t.boolean :visible
      t.references :subscriptions_subscription_template_group, foreign_key: true
      t.integer :position

      t.timestamps null: false
    end
    add_index :subscriptions_subscription_templates, :subscriptions_subscription_template_group_id, name: "index_subscriptions_subscription_template_group_id"
    add_index :subscriptions_subscription_templates, :name
    add_index :subscriptions_subscription_templates, :amount_cents
    add_index :subscriptions_subscription_templates, :interval
    add_index :subscriptions_subscription_templates, :slug
    add_index :subscriptions_subscription_templates, :visible
    add_index :subscriptions_subscription_templates, :position
  end
end
