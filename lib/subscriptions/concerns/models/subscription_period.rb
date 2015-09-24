module Subscriptions
  module Concerns
    module Models      
      module SubscriptionPeriod
        extend ActiveSupport::Concern
        
        included do
          belongs_to :subscription, class_name: "Subscriptions::Subscription"
          has_one :invoice_items_invoice, as: :invoice_itemable, class_name: "Subscriptions::InvoiceItemsInvoice"

          scope :current, ->{ where("start_at <= ? AND (end_at IS NULL OR end_at >= ?)", Time.now, Time.now) }

          validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
        end

        def to_s
          if end_at.present?
            "Subscription #{start_at.strftime("%B %-d, %Y")} to #{end_at.strftime("%B %-d, %Y")}"
          else
            "Subscription #{start_at.strftime("%B %-d, %Y")} to #{subscription.next_bill_date.strftime("%B %-d, %Y")}"
          end
        end
      end
    end
  end
end
