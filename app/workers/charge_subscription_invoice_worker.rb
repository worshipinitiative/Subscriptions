class ChargeSubscriptionInvoiceWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0 # TODO: How do we do this better?

  def perform( invoice_id )
    invoice = Invoice.find(invoice_id)

    raise "Couldn't find invoice to charge: #{invoice_id}" if invoice.nil?

    invoice.charge!
  end
end