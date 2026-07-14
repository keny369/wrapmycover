class Users::PasswordsController < Devise::PasswordsController
  invisible_captcha only: [ :create ], on_spam: :swallow_spam

  private

  def swallow_spam
    head :ok
  end
end
