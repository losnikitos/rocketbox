class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Rocketbox <noreply@example.com>")
  layout "mailer"
end
