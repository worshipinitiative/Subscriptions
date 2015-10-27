module Subscriptions
  module Concerns   
    module Subscribeable
      extend ActiveSupport::Concern
  
      included do
        has_one :subscription, as: :ownerable, class_name: "Subscriptions::Subscription"
        has_many :invoices, as: :ownerable, class_name: "Subscriptions::Invoice"
        has_many :chord_chart_downloads, as: :ownerable
      end
  
      def open_invoice
        invoices.open.first
      end
  
      def bill_outstanding_invoices!
        invoices.ready_for_payment.each(&:charge!)
        #TODO: Move this to the subscription model
        # If we get here, they all succeeded
        subscription.good_standing!
      end
    end
  end
end