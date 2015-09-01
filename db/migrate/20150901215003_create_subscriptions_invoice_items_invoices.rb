class CreateSubscriptionsInvoiceItemsInvoices < ActiveRecord::Migration
  def change
    create_table :subscriptions_invoice_items_invoices do |t|
      t.references :invoice
      t.references :invoice_itemable, polymorphic: true

      t.timestamps null: false
    end
  end
end
