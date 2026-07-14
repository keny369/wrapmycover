class Users::RegistrationsController < Devise::RegistrationsController
  invisible_captcha only: [ :create ], on_spam: :swallow_spam

  # Privacy-preserving registration: never reveal whether an email already has
  # an account. If it does, email the real owner and show the same generic
  # "check your email" response a new sign-up would produce.
  def create
    email = sign_up_params[:email].to_s.downcase.strip
    if email.present? && User.exists?(email: email)
      AccountMailer.existing_account_notice(User.find_by(email: email)).deliver_later
      set_flash_message!(:notice, :signed_up_but_unconfirmed)
      redirect_to after_inactive_sign_up_path_for(User.new) and return
    end
    super
  end

  private

  # Bots get a quiet 200 — no signal about what was detected.
  def swallow_spam
    head :ok
  end
end
