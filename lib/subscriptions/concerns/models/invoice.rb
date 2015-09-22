require 'securerandom'
module Subscriptions
  module Concerns
    module Models      
      module Invoice
        extend ActiveSupport::Concern
        
        included do
          extend FriendlyId
          friendly_id :generate_slug, use: :slugged
          
          include DateTimeScopeable

          has_many :invoice_items_invoices, class: Subscriptions::InvoiceItemsInvoice
          has_many :invoice_items, through: :invoice_items_invoices

          belongs_to :ownerable, polymorphic: true

          enum status: [ :open, :ready_for_payment, :paid, :cancelled, :refunded ]
          enum payment_status: [ :uncharged, :payment_succeeded, :payment_failed, :payment_partially_refunded, :payment_fully_refunded ]

          after_create :pull_stripe_customer_id_from_ownerable

          validates :tax_paid_cents,        numericality: { only_integer: true, greater_than_or_equal_to: 0 }
          validates :amount_refunded_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

          #TODO: Validate only one open invoice per user

        end
      
        def invoice_items
          invoice_items_invoices.includes(:invoice_itemable).collect{ |iii| iii.invoice_itemable }
        end

        def add_invoice_item( i )
          if self.new_record?
            invoice_items_invoices.new( { invoice_itemable: i } )
          else
            invoice_items_invoices.create( { invoice_itemable: i } )
          end
        end

        def ready_for_payment!
          if invoice_items.empty?
            #TODO: We should add a seperate status for this: "paid because it was empty" etc.
            self.update_attributes( status: :paid,  payment_status: :payment_succeeded)
          else
            self.update_attributes( status: :ready_for_payment )
          end
        end

        def ready_for_payment_and_charge!( async = true )
          self.update_attributes( status: :ready_for_payment )

          if async
            # TODO: Refactor so we don't have this stupid delay.
            ChargeSubscriptionInvoiceWorker.perform_in(10.seconds, id )
          else
            self.update_attributes( status: :ready_for_payment )
            ChargeSubscriptionInvoiceWorker.new.perform(id )
          end

        end

        def charge!
          raise "We can only charge invoices that are ready for payment." unless ready_for_payment?

          unless uncharged? || payment_failed?
            raise "This invoice cannot be charged because it's payment status is #{payment_status}"
          end

          # create the charge on Stripe's servers - this will charge the user's card
          Rails.logger.debug "Invoice #{id} | complete! invoked"
          begin

            Rails.logger.debug "Invoice #{id} | stripe payment_method declared"

            charge_hash = {
              :amount       => total_cents, # amount in cents
              :currency     => "usd",
              :description  => "Subscription for #{ownerable.to_s}"
            }

            if stripe_customer_id.present?
              charge_hash[:customer]  = stripe_customer_id
            else
              charge_hash[:card]      = stripe_token
            end

            if total_cents > 0
              charge = Stripe::Charge.create(charge_hash)
              self.stripe_card_type             = charge.card.type
              self.stripe_card_last_four_digits = charge.card.last4
              self.stripe_card_expiration_month = charge.card.exp_month
              self.stripe_card_expiration_year  = charge.card.exp_year
              self.stripe_card_name_on_card     = charge.card.name
              Rails.logger.debug "Invoice #{id} | Charge created: #{charge.id}"
            else
              Rails.logger.debug "Invoice #{id} | Total Amount 0.00, so no need to bill."
            end


            ActiveRecord::Base.transaction do

              Rails.logger.debug "Invoice #{id} | Updating invoice status to paid!"

              self.total_paid_cents           = total_cents
              self.tax_paid_cents             = tax_owed_cents
              self.stripe_charge_id           = charge.id if defined?(charge) && charge.present?
              self.paid_at                    = Time.now()
              self.status                     = :paid
              self.payment_status             = :payment_succeeded
              self.last_failed_payment_error  = nil
              save!

              @send_receipt = true
            end
            Rails.logger.debug "Invoice #{id} | Database transaction complete"
          rescue Stripe::CardError => e
            @send_receipt = false
            Rails.logger.error ("Stripe::CardError - #{e}")
            charge.refund if defined?(charge) && charge.present? # If anything went wrong in this process, refund the customer.
            payment_failed!(e)
            raise PaymentError, e.message
          rescue Stripe::StripeError => e
            @send_receipt = false
            Rails.logger.error ("Stripe::Error - #{e}")
            charge.refund if defined?(charge) && charge.present? # If anything went wrong in this process, refund the customer.
            payment_failed!(e)
            raise PaymentError, "I'm sorry, but there was an error with our payment processor. Your card was not charged."
          # rescue DiscountCodeError => e
          #   @send_receipt = false
          #   Rails.logger.error ("An invalid discount code use was attempted! - #{e.message}\n#{e.backtrace.join('\n')}")
          #   charge.refund if defined?(charge) && charge.present? # If anything went wrong in this process, refund the customer.
          #   self.discount_code_id = nil
          #   self.save!
          #   raise PaymentError, e.message
          rescue Exception => e
            @send_receipt = false
            Rails.logger.error ("An Unknown Exception Happened in complete! - #{e.message}\n#{e.backtrace.join('\n')}")
            charge.refund if defined?(charge) && charge.present? # If anything went wrong in this process, refund the customer.
            payment_failed!(e)
            raise PaymentError, "There was an error with our payment processor. Invoice #{self.id} was not paid."
          end

          # Rails.logger.debug "Invoice #{self.id} | Queuing the update user meta worker"
          # UpdateUserMetaDataWorker.perform_async(user.id, [:total_paid, :first_order_completed_at, :completed_orders])

          if @send_receipt
            Rails.logger.debug "Invoice #{id} | Queuing the send invoice receipt worker"
            MailWorker.perform_async('invoice_receipt_email', id)
          end
        end

        def refund
          if payment_succeeded?
            charge = Stripe::Charge.retrieve(stripe_charge_id)
            if charge.refund
              ActiveRecord::Base.transaction do
                update_attributes(payment_status: :payment_fully_refunded, amount_refunded_cents: total_paid_cents)
              end
            else
              raise "Something just went wrong when we tried to refund this invoice."
            end
          elsif partially_refunded?
            raise "NOT IMPLEMENTED: Refunding a partially refunded order is not currently implemented as we haven't had a need for it yet."
          else
            raise "Unable to refund an invoice that isn't in payment_successful status"
          end
        end


        def total_paid
          cents_to_float( total_paid_cents )
        end

        def subtotal_paid_cents
          total_paid_cents - tax_paid_cents
        end

        def subtotal_paid
          cents_to_float( subtotal_paid_cents )
        end

        def tax_paid
          cents_to_float( tax_paid_cents )
        end

        def amount_refunded
          cents_to_float( amount_refunded_cents )
        end

        def subtotal_cents
          invoice_items.sum(&:amount_cents)
        end

        def subtotal
          cents_to_float( subtotal_cents )
        end

        def tax_owed
          cents_to_float( tax_owed_cents )
        end

        def tax_owed_cents
          if tax_rate.nil?
            tax_owed_cents = 0
          else
            tax_owed_cents = (tax_rate * subtotal_cents).round
          end

          tax_owed_cents
        end

        def total
          cents_to_float( total_cents )
        end

        def total_cents
          subtotal_cents + tax_owed_cents
        end

        # Expecting 0.0 - 1.0
        def tax_rate
          if ownerable.tax_exempt?
            tax_rate = nil
          else
            tax_rate = TAX_RATES[billing_state]
          end

          tax_rate
        end

        # TODO: This has to be hella slow. We should cache this better somehow.
        def billing_state
          if stripe_token.present?
            stripe_response = Stripe::Token.retrieve(stripe_token) rescue nil
            return stripe_response.card.address_state
          elsif stripe_customer_id.present?
            return ownerable.state
          else
            return nil
          end
        end

        private

        def payment_failed!(e)
          # TODO: Do something with e.to_s, log it or whatever

          self.update_attributes( last_failed_payment_attempt_at: Time.now,
                                  failed_payment_attempt_count: failed_payment_attempt_count.to_i + 1,
                                  payment_status: :payment_failed,
                                  last_failed_payment_error: e.message )

          if failed_payment_attempt_count > 0
            if invoice_items.any?{|i| i.kind_of? SubscriptionPeriod}
              self.ownerable.subscription.suspended_payment_failed!
            end
          end
        end

        def pull_stripe_customer_id_from_ownerable
          self.update_attributes( stripe_customer_id: ownerable.stripe_customer_id )
        end

        def cents_to_float( c )
          (c.to_f / 100.0) rescue 0
        end

        def generate_slug
          "#{ownerable.id.to_s.rjust(9, '0')}#{(ownerable.invoices.where.not(slug: 'nil').count * 7).to_s.rjust(4, '0')}"
        end
      end
    end
  end
end