module Subscriptions
  module Concerns
    module Models      
      module SubscriptionTemplate
        extend ActiveSupport::Concern

        included do

          belongs_to :subscription_template_group, class_name: "Subscriptions::SubscriptionTemplateGroup"

          enum interval: { year: 0, six_month: 1, three_month: 2, month: 3 }

          acts_as_list

          before_validation :ensure_slug

          validates :slug, presence: true, uniqueness: true

          scope :visible, ->{ where(visible: true) }
          scope :ordered, ->{ order(:position) }
        end
        
        def comparison_value
          # This is the value that is used to decide if it's an upgrade or a downgrade.
          
          # It is expected that this be overwritten
          case interval
          when "year"
            amount_cents / 12
          when "six_month"
            amount_cents / 6
          when "three_month"
            amount_cents / 3
          when "month"
            amount_cents
          end
        end
        
        def value_is_greater_than(comparison_template)
          comparison_value > comparison_template.comparison_value
        end
        
        def value_is_equal_to(comparison_template)
          comparison_value == comparison_template.comparison_value
        end
        
        def value_is_less_than(comparison_template)
          comparison_value < comparison_template.comparison_value
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