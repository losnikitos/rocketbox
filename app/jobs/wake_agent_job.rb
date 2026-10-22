# frozen_string_literal: true

# One agent turn after a user's autorun chain goes quiet.
# ponytail: waits 2s so the workflow a sort just started can mark a step running. If that job is
# slower than the wait, this speaks early and the later settle speaks again. Upgrade = wake from
# the autorun job once it has started everything it is going to.
class WakeAgentJob < ApplicationJob
  queue_as :default

  WAIT = 2.seconds
  TRIGGER = "They sent a photo. The workflows have finished."

  def self.schedule(user)
    token = SecureRandom.hex(4)
    Rails.cache.write(cache_key(user), token, expires_in: 1.hour)
    set(wait: WAIT).perform_later(user.id, token)
  end

  def self.cache_key(user) = "agent-wake/#{user.id}"

  def perform(user_id, token)
    user = User.find_by(id: user_id) or return
    return unless Rails.cache.read(self.class.cache_key(user)) == token
    return if busy?(user)

    body = RocketboxAgent.reply(user, TRIGGER).content
    RocketboxAgent.deliver(user, body)
    Rails.cache.delete(self.class.cache_key(user)) if Rails.cache.read(self.class.cache_key(user)) == token
  end

  # A later settle schedules a fresh token. Waiting (approval, collect) stays quiet until it settles.
  def busy?(user)
    TransformationRun.where(status: %w[running waiting]).where(
      "(result_type = 'LibraryMedia' AND result_id IN (:media)) OR (result_type = 'Prompt' AND result_id IN (:prompts))",
      media: user.library_media.select(:id),
      prompts: user.prompts.select(:id)
    ).exists?
  end
end
