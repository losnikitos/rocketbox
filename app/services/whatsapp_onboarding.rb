# frozen_string_literal: true

# Each step's message is sent by ask!, which also stores the step in whatsapp_pending_question;
# the user's reply (photo, text or button) runs the step and asks the next one.
# ponytail: free-form messages only reach users within Meta's 24h window after their last message;
# outside it the API raises and the admin sees the error. Upgrade = approved message templates.
module WhatsappOnboarding
  MESSAGES = {
    "business_card" => <<~TEXT.strip,
      Let’s get to know your barbershop. Just send me a photo of your business card — I’ll pick up the key details without making you fill in forms or answer loads of questions.
    TEXT
    "logo" => <<~TEXT.strip,
      I couldn’t find your logo on the business card. Send me one photo of your sign or logo — that’s all I need.
    TEXT
    "instagram" => <<~TEXT.strip,
      Now let’s switch on Autopilot. It keeps your Instagram active every day with posts about your work, your barbershop, your team and everything that makes the place worth knowing about. Stories, Reels, Shorts and carousels will keep showing people what you do, what’s happening in the shop and why they should book with you.

      All you need to do is send photos of your latest cuts. While you’re working on the next one, Autopilot turns them into fresh content.

      To start publishing, tap the button below and sign in to your barbershop’s Instagram account.
    TEXT
    "instagram_connected" => <<~TEXT.strip,
      Done — Instagram’s connected. From now on, just send your latest cuts here. No need to show the client’s face — the haircut itself is enough. Send one photo, or a few photos of the same cut, at a time.

      Autopilot will publish different types of content throughout the day. If something doesn’t feel right, just delete it. Over time, it’ll learn what people respond to and make more of what works.
    TEXT
    "interior_back" => <<~TEXT.strip,
      We’ll make video content too — no expensive production crew and no filming days. Just show me what your barbershop looks like right now.

      Stand at the back of the shop and take a photo facing the windows, getting as much of the space in as you can. Something like this:
    TEXT
    "interior_front" => <<~TEXT.strip,
      Perfect. Now stand by the windows and take a photo facing the other way. Those two photos are enough for me to understand the space and where everything is.
    TEXT
    "brand_voice" => <<~TEXT.strip,
      One last thing: how bold are we going with your Instagram?

      We can keep it clean and stylish. We can make it bolder and more unexpected. Or we can go properly wild — strange ideas, unexpected stories and videos that are hard to scroll past.

      You can change this at any time.

      How are we doing it?
    TEXT
    "email" => <<~TEXT.strip
      What email should we send your monthly summary to? It’ll cover what we’ve done, what’s changed and what’s next.
    TEXT
  }.freeze

  # Photo step => MediaType slug the next WhatsApp media gets.
  MEDIA_REQUESTS = {
    "business_card" => "business-card",
    "logo" => "logo",
    "interior_back" => "interior",
    "interior_front" => "interior"
  }.freeze

  # The webhook job has no request host; Meta must reach these (dev = tunnel).
  URL_OPTIONS = { protocol: "https", host: Rails.env.production? ? "rocketbox.plus" : "dev.rocketbox.plus" }.freeze
  EXAMPLE_PHOTO_URL = "https://#{URL_OPTIONS[:host]}/onboarding/barbershop-example.jpg"

  # START_<users.whatsapp_link_code>, prefilled on /app/whatsapp.
  LINK_PATTERN = /\Astart_(\w+)\z/i

  module_function

  def ask!(user, step)
    case step
    when "instagram"
      send_link!(user, MESSAGES[step], url: login_url(user, to: "instagram"), button: "Connect Instagram")
    when "interior_back"
      deliver!(user) { |to| WhatsappCloud.send_image(phone_number_id: WhatsappCloud.phone_number_id, to:, link: EXAMPLE_PHOTO_URL, caption: MESSAGES[step]) }
    when "brand_voice"
      buttons = User.brand_voices.keys.index_with(&:capitalize)
      deliver!(user) { |to| WhatsappCloud.send_buttons(phone_number_id: WhatsappCloud.phone_number_id, to:, body: MESSAGES[step], buttons:) }
    else
      send!(user, MESSAGES.fetch(step))
    end
    user.update!(whatsapp_pending_question: step)
  end

  # Runs after the media for a photo step is stored.
  def received!(user, step, media)
    case step
    when "business_card"
      ExtractBusinessCard.call(media:)
      media.apply_extraction_to!(user) if media.reload.extraction_status == "done"
      ask!(user, user.logo.attached? ? "instagram" : "logo")
    when "logo"
      begin
        ExtractBusinessCard.extract_logo!(media)
      rescue RubyLLM::Error, Faraday::Error => e
        Rails.logger.warn("Logo extraction failed for media #{media.id}: #{e.message}")
      end
      user.copy_logo_from!(media.extracted_logo.attached? ? media.extracted_logo : media.file)
      ask!(user, "instagram")
    when "interior_back" then ask!(user, "interior_front")
    when "interior_front" then ask!(user, "brand_voice")
    end
  end

  # Returns true when the text answered the pending step.
  def answer!(user, text)
    case user.whatsapp_pending_question
    when "brand_voice"
      voice = text.strip.downcase
      return false unless User.brand_voices.key?(voice)

      user.update!(brand_voice: voice)
      ask!(user, "email")
    when "email"
      if user.update(email: text.strip, whatsapp_pending_question: nil)
        UserMailer.with(user:).email_verification.deliver_later
      else
        user.restore_attributes
        send!(user, MESSAGES["email"])
      end
    else
      return false
    end
    true
  end

  def instagram_connected!(user)
    send!(user, MESSAGES["instagram_connected"])
    ask!(user, "interior_back")
  end

  # Attaches the sender's phone to the account the code belongs to instead of creating a new one.
  def link!(phone, code)
    user = User.find_by(whatsapp_link_code: code)
    owner = User.find_by(whatsapp_phone: phone)
    reply = ->(body) { WhatsappCloud.send_text(phone_number_id: WhatsappCloud.phone_number_id, to: phone, body:) }

    if user.nil?
      reply.("This link has expired. Open WhatsApp in your Rocketbox dashboard for a new one.")
    elsif owner && owner != user
      reply.("This number is already linked to another Rocketbox account.")
    elsif user.whatsapp_phone && user.whatsapp_phone != phone
      reply.("This Rocketbox account already has a WhatsApp number. Disconnect it in your dashboard first.")
    else
      user.update!(whatsapp_phone: phone)
      user.regenerate_whatsapp_link_code
      send!(user, "WhatsApp connected.")
      ask!(user, "business_card")
    end
  end

  def login_url(user, **params)
    Rails.application.routes.url_helpers.sign_in_whatsapp_url(token: user.generate_token_for(:whatsapp_login), **params, **URL_OPTIONS)
  end

  def send_link!(user, body, url:, button:)
    deliver!(user) { |to| WhatsappCloud.send_cta_url(phone_number_id: WhatsappCloud.phone_number_id, to:, body:, display_text: button, url:) }
  end

  def send!(user, body)
    deliver!(user) { |to| WhatsappCloud.send_text(phone_number_id: WhatsappCloud.phone_number_id, to:, body:) }
  end

  def deliver!(user)
    raise WhatsappCloud::Error, "#{user.account_label} has no WhatsApp phone" if user.whatsapp_phone.blank?

    yield user.whatsapp_phone
  end
end
