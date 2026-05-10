class TestMailer < ApplicationMailer
  default from: "hello@tadaaa.uk.com"

  def hello
    mail(
      subject: "Hello from Postmark",
      to: "hello@tadaaa.uk.com",
      from: "hello@tadaaa.uk.com",
      body: "<strong>Hello</strong> dear Postmark user.",
      content_type: "text/html",
      track_opens: "true",
      message_stream: "outbound"
    )
  end
end
