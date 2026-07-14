FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "reader#{n}@example.com" }
    password { "correct-horse-battery-staple" }
    confirmed_at { Time.current }
  end
end
