class RemoveAmountRefundedCentsFromSubscriptionsInvoices < ActiveRecord::Migration
  def change
    remove_column :subscriptions_invoices, :amount_refunded_cents
  end
end
