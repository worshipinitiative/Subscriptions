module Subscriptions
  module Concerns
    module Models      
      module SubscriptionTemplate
        extend ActiveSupport::Concern

        included do

          belongs_to :subscription_template_group, class: Subscriptions::SubscriptionTemplateGroup

          enum interval: { year: 0, six_month: 1, three_month: 2, month: 3 }

          acts_as_list

          before_validation :ensure_slug

          validates :slug, presence: true, uniqueness: true

          scope :visible, ->{ where(visible: true) }
          scope :ordered, ->{ order(:position) }
        end

        private
        def ensure_slug
          return if slug.present?
          o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
          s = (0...4).map { o[rand(o.length)] }.join
          self.slug = "#{self.name.gsub(" ","_").downcase}_#{s}"
        end

      end
    end
  end
end