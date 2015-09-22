class CycleSubscriptionBillingPeriodWorker
  include Sidekiq::Worker
  sidekiq_options retry: 2 # TODO: Better retry number here?

  def perform( subscription_id )

    # WARNING. DO NOT ADD ADDITIONAL LOGIC RELATED TO THE BILLING CYCLE HERE
    # THAT MUST GO INTO THE MODEL!
    subscription = Subscriptions::Subscription.find(subscription_id)

    raise "Subscription #{subscription_id} is nil!" if subscription.nil?

    subscription.cycle_billing_period!
  end
end