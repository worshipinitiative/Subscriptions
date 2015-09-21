module Subscriptions
  module Concerns
    module Models      
      module InvoiceItemsInvoice
        extend ActiveSupport::Concern
        included do
          belongs_to :invoice
          belongs_to :invoice_itemable, polymorphic: true
        end
      end
    end
  end
end