require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  let(:user) { create(:user) }

  def checkout_completed_event(id: "evt_1", session_overrides: {})
    {
      id: id,
      object: "event",
      type: "checkout.session.completed",
      data: { object: {
        id: "cs_test_1",
        object: "checkout.session",
        mode: "payment",
        payment_intent: "pi_1",
        amount_total: 1499,
        currency: "usd",
        client_reference_id: user.id.to_s,
        metadata: { kind: "book", book_title: "Vacancy" }
      }.merge(session_overrides) }
    }
  end

  it "rejects payloads with a bad signature" do
    payload = checkout_completed_event.to_json
    post "/webhooks/stripe", params: payload, headers: {
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "t=#{Time.now.to_i},v1=deadbeef"
    }
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects unsigned payloads" do
    post "/webhooks/stripe", params: checkout_completed_event.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects oversized payloads" do
    post "/webhooks/stripe", params: "x" * (65.kilobytes),
         headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:content_too_large)
  end

  it "marks a pending purchase paid on checkout.session.completed" do
    purchase = create(:purchase, user: user, stripe_checkout_session_id: "cs_test_1")
    post_stripe_event(checkout_completed_event)
    expect(response).to have_http_status(:ok)
    expect(purchase.reload).to have_attributes(status: "paid", amount_cents: 1499,
                                               stripe_payment_intent_id: "pi_1")
  end

  it "creates the purchase from metadata when none exists locally" do
    post_stripe_event(checkout_completed_event)
    purchase = user.purchases.sole
    expect(purchase).to have_attributes(book_title: "Vacancy", status: "paid")
  end

  it "is idempotent across replayed events" do
    create(:purchase, user: user, stripe_checkout_session_id: "cs_test_1")
    2.times { post_stripe_event(checkout_completed_event) }
    expect(StripeEvent.count).to eq(1)
    expect(user.purchases.count).to eq(1)
  end

  it "records a subscription checkout with Stripe ids but leaves activation to the subscription webhook" do
    post_stripe_event(checkout_completed_event(session_overrides: {
      mode: "subscription", subscription: "sub_9", customer: "cus_9"
    }))
    expect(user.subscription).to have_attributes(stripe_subscription_id: "sub_9",
                                                 stripe_customer_id: "cus_9",
                                                 status: "incomplete")
    expect(user.reload).not_to be_pro
  end

  it "syncs subscription status changes" do
    sub = create(:subscription, user: user, stripe_subscription_id: "sub_9")
    period_end = 2.months.from_now.to_i
    post_stripe_event({
      id: "evt_sub_upd", object: "event", type: "customer.subscription.updated",
      data: { object: { id: "sub_9", object: "subscription",
                        status: "past_due", current_period_end: period_end } }
    })
    expect(sub.reload.status).to eq("past_due")
    expect(sub.current_period_end.to_i).to eq(period_end)
  end

  it "cancels on customer.subscription.deleted" do
    sub = create(:subscription, user: user, stripe_subscription_id: "sub_9")
    post_stripe_event({
      id: "evt_sub_del", object: "event", type: "customer.subscription.deleted",
      data: { object: { id: "sub_9", object: "subscription", status: "canceled" } }
    })
    expect(sub.reload.status).to eq("canceled")
    expect(user.reload).not_to be_pro
  end

  it "does NOT grant a book when payment_status is unpaid (delayed payment)" do
    create(:purchase, user: user, stripe_checkout_session_id: "cs_test_1")
    post_stripe_event(checkout_completed_event(session_overrides: { payment_status: "unpaid" }))
    expect(user.purchases.sole.status).to eq("pending")
  end

  it "grants a book when payment_status is paid" do
    create(:purchase, user: user, stripe_checkout_session_id: "cs_test_1")
    post_stripe_event(checkout_completed_event(session_overrides: { payment_status: "paid" }))
    expect(user.purchases.sole.status).to eq("paid")
  end

  it "grants later via async_payment_succeeded" do
    create(:purchase, user: user, stripe_checkout_session_id: "cs_test_1")
    post_stripe_event({
      id: "evt_async_ok", object: "event", type: "checkout.session.async_payment_succeeded",
      data: { object: { id: "cs_test_1", object: "checkout.session", mode: "payment",
                        payment_status: "paid", payment_intent: "pi_1", amount_total: 1499,
                        currency: "usd", client_reference_id: user.id.to_s,
                        metadata: { kind: "book", book_title: "Vacancy" } } }
    })
    expect(user.purchases.sole.status).to eq("paid")
  end

  it "does NOT mark a subscription active until the subscription webhook confirms it" do
    post_stripe_event(checkout_completed_event(session_overrides: {
      mode: "subscription", subscription: "sub_incomplete", customer: "cus_9", payment_status: "unpaid"
    }))
    expect(user.reload).not_to be_pro
    expect(user.subscription.status).to eq("incomplete")
    # The subscription webhook then activates it.
    post_stripe_event({
      id: "evt_sub_active", object: "event", type: "customer.subscription.updated",
      data: { object: { id: "sub_incomplete", object: "subscription", status: "active",
                        current_period_end: 1.month.from_now.to_i } }
    })
    expect(user.reload).to be_pro
  end

  it "revokes a book on charge.refunded" do
    purchase = create(:purchase, :paid, user: user, stripe_checkout_session_id: "cs_test_1")
    purchase.update!(stripe_payment_intent_id: "pi_ref")
    post_stripe_event({
      id: "evt_refund", object: "event", type: "charge.refunded",
      data: { object: { id: "ch_1", object: "charge", payment_intent: "pi_ref", refunded: true } }
    })
    expect(purchase.reload.status).to eq("refunded")
    expect(user.paid_books).to be_empty
  end

  it "revokes a book on charge.dispute.created" do
    purchase = create(:purchase, :paid, user: user, stripe_checkout_session_id: "cs_test_1")
    purchase.update!(stripe_payment_intent_id: "pi_disp")
    post_stripe_event({
      id: "evt_dispute", object: "event", type: "charge.dispute.created",
      data: { object: { id: "dp_1", object: "dispute", payment_intent: "pi_disp" } }
    })
    expect(purchase.reload.status).to eq("refunded")
  end

  it "acknowledges unhandled event types without side effects" do
    post_stripe_event({ id: "evt_x", object: "event", type: "invoice.finalized",
                        data: { object: { id: "in_1", object: "invoice" } } })
    expect(response).to have_http_status(:ok)
  end
end
