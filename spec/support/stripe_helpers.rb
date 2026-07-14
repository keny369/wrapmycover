module StripeHelpers
  # Builds a Stripe-Signature header the same way Stripe documents it:
  # HMAC-SHA256 over "<timestamp>.<payload>" with the endpoint secret.
  def stripe_signature_header(payload, secret: Billing.webhook_secret, timestamp: Time.now.to_i)
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    "t=#{timestamp},v1=#{signature}"
  end

  def post_stripe_event(payload_hash, secret: Billing.webhook_secret)
    payload = payload_hash.to_json
    # Post via a rewound StringIO so the controller must read the body the same
    # way it does behind a real Puma server (raw_post), not from parsed params.
    post "/webhooks/stripe",
         params: payload,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "RAW_POST_DATA" => payload,
           "HTTP_STRIPE_SIGNATURE" => stripe_signature_header(payload, secret: secret)
         }
  end
end

RSpec.configure { |c| c.include StripeHelpers, type: :request }
