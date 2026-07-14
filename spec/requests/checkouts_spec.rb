require "rails_helper"

RSpec.describe "Checkout", type: :request do
  let(:user) { create(:user) }
  let(:stripe_session) do
    double("Stripe::Checkout::Session", id: "cs_test_new", url: "https://checkout.stripe.com/c/pay/cs_test_new")
  end

  it "requires sign-in" do
    post checkouts_path, params: { kind: "book", book_title: "Vacancy" }
    expect(response).to redirect_to(new_user_session_path)
  end

  context "signed in" do
    before { sign_in user }

    it "creates a pending purchase and redirects to Stripe for a book" do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        mode: "payment",
        client_reference_id: user.id.to_s
      )).and_return(stripe_session)

      post checkouts_path, params: { kind: "book", book_title: "  Vacancy  " }

      purchase = user.purchases.sole
      expect(purchase).to have_attributes(book_title: "Vacancy", status: "pending",
                                          stripe_checkout_session_id: "cs_test_new")
      expect(response).to redirect_to(stripe_session.url)
      expect(response).to have_http_status(:see_other)
    end

    it "rejects a missing book title" do
      expect(Stripe::Checkout::Session).not_to receive(:create)
      post checkouts_path, params: { kind: "book", book_title: "   " }
      expect(response).to redirect_to(pricing_path)
      expect(user.purchases.count).to eq(0)
    end

    it "rejects an over-long book title" do
      expect(Stripe::Checkout::Session).not_to receive(:create)
      post checkouts_path, params: { kind: "book", book_title: "x" * 121 }
      expect(response).to redirect_to(pricing_path)
    end

    it "rejects unknown product kinds" do
      expect(Stripe::Checkout::Session).not_to receive(:create)
      post checkouts_path, params: { kind: "lifetime'; DROP TABLE users;--" }
      expect(response).to redirect_to(pricing_path)
    end

    it "starts a subscription checkout for pro" do
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        mode: "subscription"
      )).and_return(stripe_session)
      post checkouts_path, params: { kind: "pro" }
      expect(response).to redirect_to(stripe_session.url)
    end

    it "blocks a second pro subscription" do
      create(:subscription, user: user, status: "active")
      expect(Stripe::Checkout::Session).not_to receive(:create)
      post checkouts_path, params: { kind: "pro" }
      expect(response).to redirect_to(pricing_path)
    end

    it "degrades gracefully when Stripe errors" do
      allow(Stripe::Checkout::Session).to receive(:create).and_raise(Stripe::APIConnectionError.new("down"))
      post checkouts_path, params: { kind: "pro" }
      expect(response).to redirect_to(pricing_path)
      expect(flash[:alert]).to match(/couldn't start checkout/i)
    end
  end
end
