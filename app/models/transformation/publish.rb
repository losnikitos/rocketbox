# frozen_string_literal: true

# Publishes one video to the owner's Instagram as a reel, then passes that same video on.
# The permalink is stored on the step run so the finished WhatsApp line can link to it.
class Transformation::Publish < Transformation::Control
  def self.label = "Publish"

  def self.description = "Publishes the video to Instagram as a reel."

  def self.forwards? = true

  def self.inputs = { video: 1..1 }

  def finish
    media = source_media.first
    user = media.user
    ActiveStorage::Current.url_options ||= WhatsappOnboarding::URL_OPTIONS
    link = media.file.url(expires_in: 1.hour)
    id = PublishInstagramPost.call(user:, format: "reel", slides: [ { url: link, video: true } ]).first
    permalink = PublishInstagramPost.permalink(user:, media_id: id)
    run.options = run.options.merge("permalink" => permalink)
    run.save!
    run.announce!(transformation.options["done"], button: transformation.options["button"], url: permalink)
  end
end
