require "rails_helper"

RSpec.describe Purchase, type: :model do
  it "requires a title within 120 characters" do
    expect(build(:purchase, book_title: "")).not_to be_valid
    expect(build(:purchase, book_title: "x" * 121)).not_to be_valid
    expect(build(:purchase, book_title: "x" * 120)).to be_valid
  end

  it "enforces unique checkout session ids" do
    existing = create(:purchase)
    dup = build(:purchase, stripe_checkout_session_id: existing.stripe_checkout_session_id)
    expect(dup).not_to be_valid
  end

  it "marks itself paid with payment details" do
    purchase = create(:purchase)
    purchase.mark_paid!(payment_intent_id: "pi_1", amount_cents: 1499, currency: "usd")
    expect(purchase.reload).to have_attributes(status: "paid", amount_cents: 1499)
    expect(purchase.paid_at).to be_present
  end
end
