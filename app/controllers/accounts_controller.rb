class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    @purchases = current_user.purchases.order(created_at: :desc)
    @subscription = current_user.subscription
    @active_sessions = current_user.active_sessions.order(last_seen_at: :desc)
    @current_session_token_digest =
      ActiveSession.digest(session["active_session_token"].to_s)
  end
end
