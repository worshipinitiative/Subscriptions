class AddRefundedCentsColumnsToInvoices < ActiveRecord::Migration
  def change
    add_column :subscriptions_invoices, :subtotal_refunded_cents, :integer, default: 0
    add_column :subscriptions_invoices, :tax_refunded_cents, :integer, default: 0
  end
end
