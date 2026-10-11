# frozen_string_literal: true

# A recurring series of Instagram posts, e.g. "a story from photobank/ready every weekday at 9am". When auto-publish is on,
# each scheduled time publishes the folder's media posted longest ago (or never) as one RubricPost; otherwise the
# rubric only shows on the Schedule calendar.
class Rubric < ApplicationRecord
  belongs_to :user
  belongs_to :folder
  has_many :posts, -> { order(created_at: :desc) }, class_name: "RubricPost", dependent: :delete_all

  enum :format, %w[post story reel].index_by(&:itself), validate: true
  enum :color, Folder.colors, validate: true

  normalizes :name, :schedule, with: -> { it.squish }
  validates :name, :schedule, presence: true
  validate :schedule_parses, if: :schedule?
  validate { errors.add(:folder, "must be a media folder") unless folder&.media? }

  before_save(if: -> { schedule_changed? || auto_publish_changed? }) { self.next_run_at = next_occurrence }

  # The schedule as a cron, in config.time_zone unless it names a zone; Fugit would read a zoneless one in the host's.
  def cron
    parsed = Fugit.parse_cronish(schedule.to_s)
    parsed&.timezone ? parsed : Fugit.parse_cronish("#{schedule} #{Time.zone.tzinfo.name}")
  end

  def next_occurrence = cron&.next_time(Time.current)&.to_t&.in_time_zone

  def occurrences(range) = cron ? cron.within(range).map { it.to_t.in_time_zone } : []

  # Media posted by any rubric count, so a photo isn't a story and a post on the same day.
  def next_media
    user.library_media.where(folder:).of_type(("video" if reel?)).where.associated(:file_attachment)
      .left_joins(:rubric_posts).group(:id)
      .order(Arel.sql("MAX(rubric_posts.created_at) IS NOT NULL, MAX(rubric_posts.created_at), library_media.id")).first
  end

  # Advances first, so a failure never loops and missed times after downtime post once.
  def run!
    update!(next_run_at: next_occurrence)
    media = next_media or return
    PublishRubricPostJob.perform_later(posts.create!(library_media: media))
  end

  private
    def schedule_parses
      if (parsed = cron).nil?
        errors.add(:schedule, "isn't a cron line or something like “every weekday at 9am”")
      elsif parsed.rough_frequency < 1.hour
        errors.add(:schedule, "can't run more than once an hour")
      end
    end
end
