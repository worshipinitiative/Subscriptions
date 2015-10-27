class AddIndexToRefundedCentsColums < ActiveRecord::Migration
  disable_ddl_transaction!
  def change
    add_index :subscriptions_invoices, :subtotal_refunded_cents
    add_index :subscriptions_invoices, :tax_refunded_cents
  end
end
