module Subscriptions
  module Concerns
    module Models      
      module SubscriptionTemplateGroup
        extend ActiveSupport::Concern
        
        included do
          has_many :subscription_templates, class_name: "Subscriptions::SubscriptionTemplate", dependent: :destroy

          acts_as_list

          scope :visible, -> { where( visible: true ) }
        end
      end
    end
  end
end
