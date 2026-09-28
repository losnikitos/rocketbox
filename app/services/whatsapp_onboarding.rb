# frozen_string_literal: true

# ponytail: free-form messages only reach users within Meta's 24h window after their last message;
# outside it the API raises and the admin sees the error. Upgrade = approved message templates.
module WhatsappOnboarding
  QUESTIONS = {
    "name" => "What's your name?",
    "business_name" => "What is your business name?",
    "homepage_url" => "What's your website or Instagram link?"
  }.freeze

  # Keys are LibraryMedia media_types; the next WhatsApp media the user sends gets that type.
  MEDIA_REQUESTS = {
    "business_card" => "Send a photo of your business card 📇",
    "interior" => "Send a photo of your interior 📸",
    "exterior" => "Send a photo of your place from the outside 📸",
    "logo" => "Send your logo 🎨",
    "customer" => "Send a photo of a happy customer (with their permission) 🙂"
  }.freeze

  PROMPTS = QUESTIONS.merge(MEDIA_REQUESTS).freeze

  module_function

  def ask!(user, field)
    send!(user, PROMPTS.fetch(field))
    user.update!(whatsapp_pending_question: field)
  end

  def send_link!(user, url, body)
    send!(user, "#{body}\n#{url}")
  end

  def send!(user, body)
    raise WhatsappCloud::Error, "#{user.account_label} has no WhatsApp phone" if user.whatsapp_phone.blank?

    WhatsappCloud.send_text(phone_number_id: WhatsappCloud.phone_number_id, to: user.whatsapp_phone, body:)
  end
end
