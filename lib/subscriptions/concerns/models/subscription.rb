module Subscriptions
  module Concerns
    module Models
      module Subscription
        extend ActiveSupport::Concern

        included do
          include DateTimeScopeable

          belongs_to :ownerable, polymorphic: true, touch: true
          has_many :subscription_periods, class_name: "Subscriptions::SubscriptionPeriod"

          # NOTE: IF YOU ADD AN INTERVAL YOU MUST HANDLE IT IN THE CYCLE SUBSCRIPTION BILLING PERIOD METHOD AND ADD IT TO THE SUBSCRIPTION TEMPLATE MODEL!!!

          enum interval: { year: 0, six_month: 1, three_month: 2, month: 3 }

          enum status: {good_standing: 0, suspended: 1, cancelled: 2, cancel_at_end: 4, suspended_payment_failed: 5, trialing: 6, trial_expired: 7, cancelled_payment_failed: 8}

          scope :cycleable, ->{ where.not(status: [self.statuses[:suspended], self.statuses[:suspended_payment_failed], self.statuses[:cancelled], self.statuses[:cancelled_payment_failed], self.statuses[:trial_expired]]) }
          scope :ready_to_cycle, ->{ cycleable.where( "next_bill_date < ?", Time.now ) }

          validates :amount_cents_base,          numericality: { greater_than_or_equal_to: 0 }
          validates :amount_cents_next_period,   numericality: { greater_than_or_equal_to: 0 }
          validate :uniqueness_of_ownerable, on: :create

          before_create :reset_next_bill_date, if: Proc.new { |subscription| subscription.next_bill_date.blank? }
          before_create :set_initial_amount_cents
          after_create :create_open_invoice
          before_save :update_current_status_at

          @@trial_days = 7
          cattr_accessor :trial_days

          # On selecting a template this field map will be used
          # to map subscription fields to subscription template fields
          @@subscription_template_field_map = {
            amount_cents_base: :amount_cents,
            amount_cents_next_period: :amount_cents,
            interval: :interval
          }
          cattr_accessor :subscription_template_field_map

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
            status_changed_to_suspended_payment_failed
          end

          def cancelled_payment_failed!
            raise "Cannot mark status as 'cancelled_payment_failed'. Status not 'suspended_payment_failed!" unless suspended_payment_failed?
            self.update_attributes(
              status: :cancelled_payment_failed,
            )
            ownerable.cancel_outstanding_invoices!
            status_changed_to_cancelled_payment_failed
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
            status_changed_to_trial_expired
          end
        end


        class_methods do
          def new_from_template( t, subscription_params = {} )
            subscription = Subscriptions::Subscription.new( subscription_params )
            subscription.assign_mapped_fields_for_template(t)
            return subscription
          end

          def cycle_subscriptions( async = true )
            Subscriptions::Subscription.ready_to_cycle.find_each do |s|
              if async
                CycleSubscriptionBillingPeriodWorker.perform_async( s.id )
              else
                s.cycle_billing_period!
              end
            end
          end


        end

        def current_subscription_period
          subscription_periods.current.order( start_at: :desc ).limit(1).first
        end

        def previous_subscription_period
          subscription_periods.order( start_at: :desc ).limit(2)[1] rescue nil
        end

        # Create a subscription period for the upcoming month
        # Add that to the open invoice for the user
        # Mark that invoice as ready to be charged
        # Create a new invoice to hold items like add-ons over the next month
        def cycle_billing_period!(charge_synchronously = false)
          Rails.logger.debug( "subscription#cycle_billing_period!" )

          if next_bill_date > Time.now
            Rails.logger.debug "Not time to bill Subscription #{id}!"
            return
          end

          raise "Subscription #{id} was supposed to bill over 14 days ago! Has something gone wrong?" unless next_bill_date > 14.days.ago

          # Handle cancel_at_end
          if cancel_at_end?
            self.cancelled!
            if current_subscription_period.present? && current_subscription_period.end_at.nil?
              current_subscription_period.update_attributes( end_at: Time.now )
            end
            # We mark the open invoice as ready for payment so any outstanding add-on downloads get paid for.
            ownerable.open_invoice.ready_for_payment_and_charge!
            create_open_invoice
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
              create_open_invoice
              self.save
              return
            end
          end

          raise "Subscription #{id} isn't in good standing. It's in #{status}. Can't cycle." unless good_standing? || trialing?

          raise "Couldn't find owner for subscription #{id}" if ownerable.nil?

          open_invoice = ownerable.open_invoice

          if open_invoice.nil?
            raise "No open invoice for #{ownerable_type} #{ownerable}"
          end

          last_subscription_period = current_subscription_period

          if last_subscription_period.nil? #This is the first month (ever, or in a long time)
            start_at = Time.now
          else
            last_subscription_period.update_attributes( end_at: 1.second.ago )
            start_at = last_subscription_period.end_at + 1.second
          end

          Rails.logger.debug( "subscription#cycle_billing_period!  Creating next subscription period" )
          next_subscription_period = subscription_periods.build(
            {
              start_at: start_at,
              end_at: nil,
              amount_cents: amount_cents_next_period
            }
          )

          next_subscription_period = prepare_next_subscription_period(next_subscription_period, last_subscription_period)

          next_subscription_period.save

          # Update the subscription for this upcoming month
          self.amount_cents_next_period   = amount_cents_base

          # Set the next billing date.
          if trialing?
            self.next_bill_date = Subscriptions::Subscription.trial_days.days.from_now
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

          prepare_subscription_for_next_subscription_period(next_subscription_period)

          save

          open_invoice.add_invoice_item( next_subscription_period )

          # If their trial is expired, we need to mark it as good standing.
          # If the billing here fails, it will mark their subscrition as suspended_payment_failed
          if trial_expired?
            self.good_standing!
          end

          # Create a new open invoice for charges that come up between now and next month
          Rails.logger.debug( "subscription#cycle_billing_period!  Creating new open invoice" )
          ownerable.invoices.create( { status: :open } )

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

        def interval_to_duration
          case interval
          when "year"
            1.year
          when "six_month"
            6.months
          when "three_month"
            3.months
          when "month"
            1.month
          end
        end

        def change_plan_to_template!(current_subscription = nil, new_subscription_template, cycle_billing_period_synchronously = false)
          Rails.logger.debug "change_plan_to_template!"
          if trialing? || trial_expired? || cancelled? || cancelled_payment_failed?

            # If it's cancelled or trial_expired then just change to the new
            # template, reset bill date, and cycle.
            # If trialing, don't cycle
            was_trialing = trialing?
            assign_mapped_fields_for_template(new_subscription_template)
            reset_next_bill_date unless was_trialing
            # Set their status to :good_standing now. They will cycle, and trigger an invoice which will update the status if necessarily
            self.status = :good_standing unless was_trialing
            if self.save
              unless was_trialing
                # We need to cycle the billing period now
                cycle_billing_period!(cycle_billing_period_synchronously)
              end
            end

            return self
          end

          # If they're at cancel_at_end we're assuming they're trying to reinstate their subscription by upgrading
          self.uncancel_at_end! if cancel_at_end?



          if current_subscription.present? && current_subscription == new_subscription_template
            Rails.logger.debug "Nothing to change!"
            errors.add(:interval, "That's the plan you're currently on!")
            return false
          end




          if new_subscription_template.value_is_equal_to(current_subscription)
            # I'm changing to something in the same template group. Effectively
            # I'm just changing my interval. apply at the end of the period.
            Rails.logger.debug "Matching Group - Changing interval only!"
            assign_mapped_fields_for_template(new_subscription_template)
            self.save

          else # I'm changing to a new template value

            # New Plan / value
            if new_subscription_template.interval_to_duration < current_subscription.interval_to_duration
              Rails.logger.debug "Cannot change to a shorter interval"
              errors.add(:interval, "You cannot change to a shorter interval")
              return false
            end

            if new_subscription_template.value_is_greater_than(current_subscription)
              # Upgrade
              Rails.logger.debug "Upgrade detected"
              assign_mapped_fields_for_template(new_subscription_template)
              # The next period is reduced in cost bt the amount of value
              # remaining on the current period.
              perform_prorating(new_subscription_template)
              reset_next_bill_date
              self.save

              # We need to cycle the billing period now
              cycle_billing_period!(cycle_billing_period_synchronously)

              return self
            else
              # Downgrade
              Rails.logger.debug "Downgrade detected"
              assign_mapped_fields_for_template(new_subscription_template)
              self.save
            end
          end
          return self
        end

        def value_cents_remaining_on_current_period
          return  0 unless active?
          if current_subscription_period.present?
            start_date = current_subscription_period.start_at
            end_date = self.next_bill_date

            total_days_in_period = ((end_date - start_date) / (24 * 60 * 60)).round
            days_left_in_period = ((end_date - Time.now) / (24 * 60 * 60)).round

            value_cents_remaining = (self.amount_cents_base * (days_left_in_period.to_f/total_days_in_period)).round
          else
            raise "No current subscription period found for subscription #{self.id}"
          end
        end

        def subscription_template
          # Note: If you add custom fields to the subscription templates model, you will want to override this method to check for those as well

          # This attempts to find a public subscription template that matches the current subscription settings.

          #TODO: Use the mapped fields to do this lookup
          Subscriptions::SubscriptionTemplate.visible.find_or_initialize_by(interval: Subscriptions::Subscription.intervals[interval], amount_cents: amount_cents_base)
        end

        def active?
          good_standing? || cancel_at_end? || trialing?
        end

        def assign_mapped_fields_for_template(template)
          Subscriptions::Subscription.subscription_template_field_map.each do |s, t|
            self.send("#{s}=", template.send(t))
          end
        end

        def unsuspend_for_payment_failed!
          return if good_standing? # Nothing to see here!

          # What we're doing here is checking to see if their subscription was
          # supposed to renew in the next 7 days (or in the past). If it was, we're resetting their bill date so they don't get billed again right away.
          if self.next_bill_date <= 7.days.from_now
            self.next_bill_date = interval_from_now
            self.save
          end
          good_standing!
        end

        def update_first_paid_at!(force = false)
          return unless force || self.first_paid_at.nil?
          self.update_attributes(
            first_paid_at: (ownerable.invoices.paid.where("total_paid_cents > 0").order(paid_at: :asc).first.paid_at rescue nil)
          )
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

        def status_changed_to_cancelled_payment_failed
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
          when "month"
            1.month.from_now
          end
        end

        def uniqueness_of_ownerable
          errors.add(:ownerable, "Must be unique") if Subscriptions::Subscription.where(ownerable_type: ownerable_type, ownerable_id: ownerable_id).count > 0
        end

        def update_current_status_at
          if self.status_changed?
            self.current_status_at = Time.now
          end
        end

        ####################################
        ## Hooks mid-cycle billing period ##
        ####################################

        def prepare_next_subscription_period(next_subscription_period, current_subscription_period)
          return next_subscription_period
        end

        def prepare_subscription_for_next_subscription_period(next_subscription_period)
          return
        end

        #######################################
        ## Hooks mid-change_plan_to_template ##
        #######################################

        def perform_prorating(new_subscription_template)
          self.amount_cents_next_period   = new_subscription_template.amount_cents - value_cents_remaining_on_current_period
        end
      end
    end
  end
end
