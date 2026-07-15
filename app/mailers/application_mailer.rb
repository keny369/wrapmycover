class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_SENDER", "no-reply@wrapmycover.com")
  layout "mailer"
end
