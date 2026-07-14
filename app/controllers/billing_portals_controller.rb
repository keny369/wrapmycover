class BillingPortalsController < ApplicationController
  before_action :authenticate_user!

  def create
    customer_id = current_user.subscription&.stripe_customer_id
    return redirect_to account_path, alert: "No billing profile yet." if customer_id.blank?

    portal = Stripe::BillingPortal::Session.create(
      customer: customer_id,
      return_url: account_url
    )
    redirect_to portal.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error("[stripe] portal failed: #{e.class} #{e.message}")
    redirect_to account_path, alert: "Couldn't open the billing portal. Please try again."
  end
end
