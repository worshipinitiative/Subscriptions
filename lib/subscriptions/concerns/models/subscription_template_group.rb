module Subscriptions
  module Concerns
    module Models      
      module SubscriptionTemplateGroup
        extend ActiveSupport::Concern
        
        included do
          has_many :subscription_templates, class: Subscriptions::SubscriptionTemplate

          scope :visible, -> { where( visible: true ) }
        end
      end
    end
  end
end
