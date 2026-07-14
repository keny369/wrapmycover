FactoryBot.define do
  factory :purchase do
    user
    book_title { "Vacancy" }
    sequence(:stripe_checkout_session_id) { |n| "cs_test_#{n}" }
    status { "pending" }

    trait :paid do
      status { "paid" }
      paid_at { Time.current }
      amount_cents { 1499 }
    end
  end
end
