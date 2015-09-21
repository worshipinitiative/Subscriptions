class AddDefaultForInvoiceAmountRefundedCents < ActiveRecord::Migration
  def change
    change_column :subscriptions_invoices, :amount_refunded_cents, :integer, default: 0
  end
end
