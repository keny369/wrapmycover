# This file is idempotent and safe to rerun. Production seed credentials must be
# passed in via WRAPMYCOVER_SEED_ACCOUNT_PASSWORD; do not commit real passwords.

seed_password = ENV.fetch("WRAPMYCOVER_SEED_ACCOUNT_PASSWORD") do
  if Rails.env.production?
    raise "Set WRAPMYCOVER_SEED_ACCOUNT_PASSWORD before running production seeds."
  end

  "development-seed-password"
end

seeded_at = Time.current

def seed_user!(email:, password:, admin:, now:)
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(
    admin: admin,
    confirmed_at: user.confirmed_at || now,
    confirmation_sent_at: nil,
    confirmation_token: nil,
    failed_attempts: 0,
    locked_at: nil,
    unconfirmed_email: nil,
    unlock_token: nil
  )

  # Owner-requested seed accounts may use a password below the public 12-char
  # signup minimum. Preserve the public policy while setting the seeded hash.
  user.skip_confirmation_notification!
  user.skip_password_change_notification!
  user.encrypted_password = Devise::Encryptor.digest(User, password)
  user.save!(validate: false)
  user
end

admin_user = seed_user!(
  email: "admin@lumenandlever.com",
  password: seed_password,
  admin: true,
  now: seeded_at
)

paid_user = seed_user!(
  email: "user@lumenandlever.com",
  password: seed_password,
  admin: false,
  now: seeded_at
)

pro_user = seed_user!(
  email: "prouser@lumenandlever.com",
  password: seed_password,
  admin: false,
  now: seeded_at
)

free_user = seed_user!(
  email: "free@lumenandlever.com",
  password: seed_password,
  admin: false,
  now: seeded_at
)

paid_purchase = paid_user.purchases.find_or_initialize_by(
  stripe_checkout_session_id: "seed_user_lumenandlever_book_checkout"
)
paid_purchase.assign_attributes(
  book_key: "seed-user-lumenandlever-book",
  book_title: "Seeded $14 book unlock",
  amount_cents: 1499,
  currency: "usd",
  paid_at: paid_purchase.paid_at || seeded_at,
  status: "paid",
  stripe_payment_intent_id: "seed_user_lumenandlever_payment"
)
paid_purchase.save!

pro_subscription = pro_user.subscription || pro_user.build_subscription
pro_subscription.assign_attributes(
  current_period_end: 1.year.from_now,
  status: "active",
  stripe_customer_id: "seed_prouser_lumenandlever_customer",
  stripe_subscription_id: "seed_prouser_lumenandlever_subscription"
)
pro_subscription.save!

puts "Seeded #{admin_user.email} as admin."
puts "Seeded #{paid_user.email} with a paid $14 book unlock."
puts "Seeded #{pro_user.email} with an active $99 Pro subscription."
puts "Seeded #{free_user.email} as a confirmed free user."
