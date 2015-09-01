module Subscriptions
  class SubscriptionTemplateGroup < ActiveRecord::Base
    has_many :subscription_templates

    scope :visible, -> { where( visible: true ) }
  end
end
