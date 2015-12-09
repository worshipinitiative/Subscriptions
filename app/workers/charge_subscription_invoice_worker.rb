class ChargeSubscriptionInvoiceWorker
  include Sidekiq::Worker
  # We don't retry. It is your job to retry them if needed.
  sidekiq_options retry: false

  def perform( invoice_id )
    invoice = Subscriptions::Invoice.find(invoice_id)

    raise "Couldn't find invoice to charge: #{invoice_id}" if invoice.nil?
    begin
      invoice.charge!
    rescue Subscriptions::PaymentError => e
      Rails.logger.info "Invoice #{invoice_id} failed to charge with error: #{e.message}"
    end
  end
end