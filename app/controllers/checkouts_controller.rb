class CheckoutsController < ApplicationController
  before_action :authenticate_user!

  KINDS = %w[book pro].freeze
  BOOK_TITLE_MAX = 120
  BOOK_KEY_FORMAT = /\A[0-9a-fA-F-]{16,64}\z/

  def create
    kind = params[:kind].to_s
    return invalid_request("Unknown product.") unless KINDS.include?(kind)

    if kind == "book"
      title = params[:book_title].to_s.strip
      if title.blank? || title.length > BOOK_TITLE_MAX
        return invalid_request("Book title is required (max #{BOOK_TITLE_MAX} characters).")
      end
      # Optional per-project key from the editor, so the purchase binds to the
      # exact cover being designed. Rejected unless it looks like an id.
      book_key = params[:book_key].to_s.strip.presence
      return invalid_request("Invalid book reference.") if book_key && !book_key.match?(BOOK_KEY_FORMAT)

      session = create_book_session(title, book_key)
      current_user.purchases.create!(
        book_title: title,
        book_key: book_key,
        stripe_checkout_session_id: session.id,
        status: "pending"
      )
    else
      return invalid_request("You already have an active Pro subscription.") if current_user.pro?
      session = create_pro_session
    end

    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error("[stripe] checkout create failed: #{e.class} #{e.message}")
    redirect_to pricing_path, alert: "We couldn't start checkout. Please try again."
  end

  def success
    @purchase = current_user&.purchases&.find_by(stripe_checkout_session_id: params[:session_id].to_s)
  end

  def cancel
  end

  private

  def invalid_request(message)
    redirect_to pricing_path, alert: message, status: :see_other
  end

  def create_book_session(title, book_key = nil)
    Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [ { price: Billing::BOOK_PRICE_ID, quantity: 1 } ],
      customer_email: current_user.email,
      client_reference_id: current_user.id.to_s,
      metadata: { kind: "book", book_title: title, user_id: current_user.id, book_key: book_key },
      success_url: "#{checkout_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: checkout_cancel_url
    )
  end

  def create_pro_session
    Stripe::Checkout::Session.create(
      mode: "subscription",
      line_items: [ { price: Billing::PRO_PRICE_ID, quantity: 1 } ],
      customer_email: current_user.email,
      client_reference_id: current_user.id.to_s,
      metadata: { kind: "pro", user_id: current_user.id },
      success_url: "#{checkout_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: checkout_cancel_url
    )
  end
end
