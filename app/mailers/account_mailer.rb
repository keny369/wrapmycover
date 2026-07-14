class AccountMailer < ApplicationMailer
  # Sent when someone attempts to register with an email that already has an
  # account — lets the real owner know, without revealing account existence to
  # the person who submitted the form.
  def existing_account_notice(user)
    @user = user
    mail(to: user.email, subject: "Someone tried to sign up with your email")
  end
end
