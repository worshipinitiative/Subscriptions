module Subscriptions
  module Concerns
    module Models      
      module Subscription
        extend ActiveSupport::Concern

        included do
          include DateTimeScopeable
          
          belongs_to :ownerable, polymorphic: true
          has_many :subscription_periods, class_name: "Subscriptions::SubscriptionPeriod"
    
          # NOTE: IF YOU ADD AN INTERVAL YOU MUST HANDLE IT IN THE CYCLE SUBSCRIPTION BILLING PERIOD METHOD AND ADD IT TO THE SUBSCRIPTION TEMPLATE MODEL!!!
    
          enum interval: { year: 0, six_month: 1, three_month: 2, month: 3 }
    
          enum status: {good_standing: 0, suspended: 1, cancelled: 2, cancel_at_end: 4, suspended_payment_failed: 5, trialing: 6, trial_expired: 7}

          validates :amount_cents_base,          numericality: { greater_than_or_equal_to: 0 }
          validates :amount_cents_next_period,   numericality: { greater_than_or_equal_to: 0 }
          validate :uniqueness_of_ownerable, on: :create

          before_create :reset_next_bill_date, if: Proc.new { |subscription| subscription.next_bill_date.blank? }
          before_create :set_initial_amount_cents
          after_create :create_open_invoice
          
          TRIAL_DAYS = 7
        end


        class_methods do
          def new_from_template( t, subscription_params = {} )
            subscription = Subscriptions::Subscription.new( subscription_params )

            subscription.interval = t.interval
            subscription.amount_cents_base   = t.amount_cents
            subscription.amount_cents_next_period = t.amount_cents
    
            return subscription
          end

          def cycle_subscriptions( async = true )
            Subscriptions::Subscription.where( "next_bill_date < ?", Time.now ).each do |s|
              if async
                CycleSubscriptionBillingPeriodWorker.perform_async( s.id )
              else
                s.cycle_billing_period!
              end
            end
          end

        end

        def current_subscription_period
          subscription_periods.current.order("start_at DESC").first
        end

        # TODO: This doesn't work unless the previous subscription period started over a week ago.
        def previous_subscription_period
          subscription_periods.where( "start_at <= ? AND end_at IS NULL", 1.week.ago ).order( start_at: :desc ).first
        end

        # Create a subscription period for the upcoming month
        # Add that to the open invoice for the user
        # Mark that invoice as ready to be charged
        # Create a new invoice to hold items like add-ons over the next month
        def cycle_billing_period!(charge_synchronously = false)
          Rails.logger.debug( "subscription#cycle_billing_period!" )

          raise "Not time to bill Subscription #{id}!" unless next_bill_date <= Time.now
          raise "Subscription #{id} was supposed to bill over a week ago! Has something gone wrong?" unless next_bill_date >= 1.week.ago

          # Handle cancel_at_end
          if cancel_at_end?
            self.cancelled!
            if previous_subscription_period.end_at.nil?
              previous_subscription_period.update_attributes( end_at: Time.now )
            end
            # We mark the open invoice as ready for payment so any outstanding add-on downloads get paid for.
            ownerable.open_invoice.ready_for_payment_and_charge!
            self.save
            return
          end
    
          # Handle trialing
          if trialing?
            if subscription_periods.size == 0
              # This is the first subscription period.
            elsif ownerable.has_valid_card_on_file?
              # They have a card, let's bill them.
              self.good_standing!
            else
              # They don't have a card on file, so their trial is expiring
              self.trial_expired!
              # We mark the open invoice as ready for payment so anything attached to it will attempt to get billed.
              ownerable.open_invoice.ready_for_payment_and_charge!
              self.save
              return
            end
          end
    
          raise "Subscription #{id} isn't in good standing. Can't cycle." unless good_standing? || trialing?

          raise "Couldn't find owner for subscription #{id}" if ownerable.nil?

          open_invoice = ownerable.open_invoice

          if open_invoice.nil?
            raise "No open invoice for #{ownerable_type} #{ownerable}"
          end

          last_subscription_period = previous_subscription_period

          if last_subscription_period.nil? #This is the first month (ever, or in a long time)
            start_at = Time.now
          else
            last_subscription_period.update_attributes( end_at: Time.now )
            start_at = last_subscription_period.end_at + 1.second
          end

          Rails.logger.debug( "subscription#cycle_billing_period!  Creating next subscription period" )
          next_subscription_period = subscription_periods.create(
            {
              start_at: start_at,
              end_at: nil,
              amount_cents: amount_cents_next_period,
              #paid: false
            }
          )

          # Update the subscription for this upcoming month
          self.amount_cents_next_period   = amount_cents_base

          # Set the next billing date.
          if trialing?
            self.next_bill_date = TRIAL_DAYS.days.from_now
          else
            case interval.to_sym
            when :year
              self.next_bill_date += 12.months
            when :six_month
              self.next_bill_date +=  6.months
            when :three_month
              self.next_bill_date +=  3.months
            else
              self.next_bill_date +=  1.month
            end
          end

          save
    
          open_invoice.add_invoice_item( next_subscription_period )
          if charge_synchronously
            begin
              open_invoice.ready_for_payment!
              open_invoice.charge!
            rescue => e
              Rails.logger.error( "subscription#cycle_billing_period!  Invoice #{open_invoice.id} failed to charge")
              Rails.logger.error( "#{e.message}" )
            end
          else
            open_invoice.ready_for_payment_and_charge!
          end

          # Create a new open invoice for charges that come up between now and next month
          Rails.logger.debug( "subscription#cycle_billing_period!  Creating new open invoice" )
          ownerable.invoices.create( { status: :open } )
    
          return self
        end

        def interval_to_s
          case interval
          when "year"
            "yr"
          when "six_month"
            "six months"
          when "three_month"
            "three months"
          when "month"
            "mo"
          end
        end

        def cancel_at_end!
          raise "Cannot cancel at end. Status not in good standing!" unless good_standing? || trialing?
          self.update_attributes(
            status: :cancel_at_end,
            amount_cents_next_period: 0
          )
          status_changed_to_cancel_at_end
        end

        def uncancel_at_end!
          raise "Cannot uncancel. Status not cancel at end!" unless cancel_at_end?
          self.update_attributes(
            status: :good_standing,
            amount_cents_next_period: amount_cents_base
          )
          status_reinstated
        end
        
        def good_standing!
          self.update_attributes(
            status: :good_standing,
          )
          status_changed_to_good_standing
        end
        
        def suspended!
          self.update_attributes(
            status: :suspended,
          )
          status_changed_to_suspended
        end
        
        def cancelled!
          self.update_attributes(
            status: :cancelled,
          )
          status_changed_to_cancelled
        end
        
        def suspended_payment_failed!
          self.update_attributes(
            status: :suspended_payment_failed,
          )
          status_changed_to_suspended_payment_failed!
        end
        
        def trialing!
          self.update_attributes(
            status: :trialing,
          )
          status_changed_to_trialing
        end
        
        def trial_expired!
          self.update_attributes(
            status: :trial_expired,
          )
          status_changed_to_trialexpired
        end

        def change_plan_to_template!( new_subscription_template, allow_interval_change = false )

          previous_amount_cents_base = amount_cents_base

          if interval != new_subscription_template.interval
            raise "Cannot change your interval" unless allow_interval_change
            self.interval = new_subscription_template.interval
            # This is in place so we can manually do this change through the console.
            # Due to the logic below, if you're going from monthly to annual on the same plan, you're going to get billed immediately (treated as an upgrade).
            # If you are going from annual to monthly, the change will take effect at the end of the billing period.
            # Before we can enable users to make this change themselves, we need to improve the logic below to handle this better.
          end


          self.amount_cents_base          = new_subscription_template.amount_cents
          self.amount_cents_next_period   = new_subscription_template.amount_cents

          if new_subscription_template.amount_cents < previous_amount_cents_base
            # We're downgrading
            # Just need to save
            self.save

          elsif new_subscription_template.amount_cents > previous_amount_cents_base
            # We're upgrading
            # Need to reset the billing period, save, and then cycle
            reset_next_bill_date
            self.save
            cycle_billing_period!

          else
            # TODO: We probably want to allow people to change plans to something with the same cost but different download counts.
            raise "Cannot change plan to something with the same value as your current subscription."
          end
        end

        def subscription_template
          # This attempts to find a public subscription template that matches the current subscription settings.
          SubscriptionTemplate.find_by(interval: Subscription.intervals[interval], amount_cents: amount_cents_base)
        end

        def active?
          good_standing? || cancel_at_end? || trialing?
        end
        
        
        ########################
        # Hooks
        ########################
        
        def status_changed_to_good_standing
        end
        
        def status_changed_to_suspended
        end
        
        def status_changed_to_cancelled
        end
        
        def status_changed_to_cancel_at_end
        end
        
        def status_changed_to_suspended_payment_failed
        end
        
        def status_changed_to_trialing
        end
        
        def status_changed_to_trial_expired
        end
        
        def status_reinstated
          # This is called when the user "uncancel_at_end"s their subscription before the end of the period.
        end
        
        
        #########################
        private
        #########################

        def set_initial_amount_cents
          if trialing?
            self.amount_cents_next_period = 0
          end
        end

        # Resets the next bill date to today, or the 28th if we're after that.
        def reset_next_bill_date
          Rails.logger.debug( "subscription#reset_next_bill_date" )

          # Make sure we're always on a 28th or earlier
          # Using the time zone thing here feels pretty dirty.
          Time.use_zone('Central Time (US & Canada)') do
            subscription_bill_date_base = Time.zone.now.beginning_of_day
            if subscription_bill_date_base.day > 28
              subscription_bill_date_base -= (subscription_bill_date_base.day - 28).days
            end
            self.next_bill_date = subscription_bill_date_base
          end
        end

        def create_open_invoice
          Rails.logger.debug( "subscription#create_open_invoice" )

          # Create an open invoice for any add-ons that show up this month.
          invoice = ownerable.invoices.create( { status: :open } )
          if !invoice.valid?
            Rails.logger.debug("Unable to create new invoice: #{invoice.errors.full_messages}")
          end
        end

        def interval_from_now
          case interval
          when "year"
            1.year.from_now
          when "six_month"
            6.months.from_now
          when "three_month"
            3.months.from_now
          when month
            1.month.from_now
          end
        end

        def uniqueness_of_ownerable
          errors.add(:ownerable, "Must be unique") if Subscriptions::Subscription.where(ownerable_type: ownerable_type, ownerable_id: ownerable_id).count > 0
        end
    
      end
    end
  end
end