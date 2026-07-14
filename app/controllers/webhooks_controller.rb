class WebhooksController < ActionController::API
  MAX_PAYLOAD_BYTES = 64.kilobytes

  # Stripe is the only caller; authenticity comes from signature verification,
  # idempotency from the stripe_events unique index.
  def stripe
    return head :content_too_large if request.content_length.to_i > MAX_PAYLOAD_BYTES

    # raw_post reads and rewinds the body, so it works even though Rails has
    # already parsed the JSON into params (a plain body.read would be at EOF).
    payload = request.raw_post.to_s
    return head :content_too_large if payload.bytesize > MAX_PAYLOAD_BYTES

    event = Stripe::Webhook.construct_event(
      payload,
      request.env["HTTP_STRIPE_SIGNATURE"].to_s,
      Billing.webhook_secret
    )

    return head :ok if StripeEvent.exists?(event_id: event.id)

    ActiveRecord::Base.transaction do
      handle_event(event)
      StripeEvent.create!(event_id: event.id, event_type: event.type)
    end
    head :ok
  rescue ActiveRecord::RecordNotUnique
    head :ok # concurrent duplicate delivery
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def handle_event(event)
    object = event.data.object
    case event.type
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      handle_checkout_completed(object)
    when "checkout.session.async_payment_failed"
      handle_checkout_failed(object)
    when "customer.subscription.created", "customer.subscription.updated"
      sync_subscription(object)
    when "customer.subscription.deleted"
      cancel_subscription(object)
    when "charge.refunded", "charge.dispute.created"
      handle_charge_reversed(object)
    end
  end

  def handle_checkout_completed(session)
    case session.mode
    when "payment"
      # Only grant on a genuinely-paid session. Delayed-payment methods fire
      # completed with payment_status "unpaid" and settle later via
      # async_payment_succeeded — entitlement must wait for that.
      return unless paid_status?(session.try(:payment_status))

      purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
      purchase ||= build_purchase_from(session)
      purchase&.mark_paid!(
        payment_intent_id: session.payment_intent,
        amount_cents: session.amount_total,
        currency: session.currency
      )
    when "subscription"
      user = User.find_by(id: session.client_reference_id)
      return unless user

      # Record the Stripe ids but do NOT assume "active": the real status
      # arrives via customer.subscription.created/updated. First invoice may
      # still be incomplete/past_due.
      subscription = Subscription.find_or_initialize_by(user: user)
      subscription.stripe_subscription_id = session.subscription
      subscription.stripe_customer_id = session.customer
      subscription.status = "incomplete" if subscription.new_record?
      subscription.save!
    end
  end

  def handle_checkout_failed(session)
    purchase = Purchase.find_by(stripe_checkout_session_id: session.id)
    purchase&.update!(status: "pending")
  end

  def handle_charge_reversed(charge)
    payment_intent_id = charge.try(:payment_intent)
    return if payment_intent_id.blank?

    Purchase.where(stripe_payment_intent_id: payment_intent_id, status: "paid")
            .update_all(status: "refunded", updated_at: Time.current)
  end

  def paid_status?(payment_status)
    # nil covers older API shapes lacking the field; treat as paid there.
    payment_status.nil? || payment_status == "paid" || payment_status == "no_payment_required"
  end

  def build_purchase_from(session)
    user = User.find_by(id: session.client_reference_id)
    return nil unless user

    user.purchases.create!(
      book_title: session.metadata.try(:[], "book_title").presence || "Untitled book",
      stripe_checkout_session_id: session.id,
      status: "pending"
    )
  end

  def sync_subscription(stripe_sub)
    subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return unless subscription

    period_end = stripe_sub.try(:current_period_end)
    subscription.update!(
      status: stripe_sub.status,
      current_period_end: period_end ? Time.zone.at(period_end) : nil
    )
  end

  def cancel_subscription(stripe_sub)
    Subscription.find_by(stripe_subscription_id: stripe_sub.id)&.update!(status: "canceled")
  end
end
