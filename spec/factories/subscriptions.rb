FactoryBot.define do
  factory :subscription do
    user
    sequence(:stripe_subscription_id) { |n| "sub_test_#{n}" }
    stripe_customer_id { "cus_test_1" }
    status { "active" }
    current_period_end { 1.month.from_now }
  end
end
