class Subscription < ApplicationRecord
  belongs_to :user

  ACTIVE_STATUSES = %w[active trialing].freeze

  validates :stripe_subscription_id, presence: true, uniqueness: true

  def active?
    status.in?(ACTIVE_STATUSES) &&
      (current_period_end.nil? || current_period_end.future?)
  end
end
