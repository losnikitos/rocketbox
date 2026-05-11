class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Rocketbox <noreply@rocketbox.plus>")
  layout "mailer"
end
