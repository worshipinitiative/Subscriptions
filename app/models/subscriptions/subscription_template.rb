module Subscriptions
  class SubscriptionTemplate < ActiveRecord::Base
    belongs_to :subscription_template_group

    enum interval: { year: 0, six_month: 1, three_month: 2, month: 3 }

    acts_as_list

    before_validation :ensure_code

    validates :code, presence: true, uniqueness: true

    scope :visible, ->{ where(visible: true) }
    scope :ordered, ->{ order(:position) }

    private
    def ensure_code
      return if code.present?
      o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
      s = (0...4).map { o[rand(o.length)] }.join
      self.code = "#{self.name.gsub(" ","_").downcase}_#{s}"
    end
  end
  
  end
end
