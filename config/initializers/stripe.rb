Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
Stripe.max_network_retries = 2

module Billing
  # Price IDs come from the Stripe dashboard (test mode locally).
  BOOK_PRICE_ID = ENV.fetch("STRIPE_PRICE_BOOK", "price_book_placeholder")
  PRO_PRICE_ID  = ENV.fetch("STRIPE_PRICE_PRO", "price_pro_placeholder")

  # Fail closed, lazily: resolved when a webhook actually arrives (not at boot
  # or asset-precompile, which must not require the secret). In production a
  # missing secret raises at the point of use, so a misconfigured deploy
  # rejects webhooks rather than silently verifying against a placeholder.
  def self.webhook_secret
    ENV["STRIPE_WEBHOOK_SECRET"].presence ||
      (Rails.env.production? ? raise("STRIPE_WEBHOOK_SECRET is not set") : "whsec_placeholder")
  end
end
