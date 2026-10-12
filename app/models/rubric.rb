# frozen_string_literal: true

# A recurring series of Instagram posts, e.g. "a story from ready/stories every weekday at 9am". When auto-publish is on,
# each scheduled time publishes the folder's media posted longest ago (or never) as one RubricPost; otherwise the
# rubric only shows on the Schedule calendar. With tags, it only takes the folder's media with all of them.
class Rubric < ApplicationRecord
  belongs_to :user
  belongs_to :folder
  has_many :posts, -> { order(scheduled_at: :desc) }, class_name: "RubricPost", dependent: :delete_all

  enum :format, %w[post story reel].index_by(&:itself), validate: true
  enum :color, Folder.colors, validate: true

  normalizes :name, :schedule, with: -> { it.squish }
  normalizes :tag_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq }
  validates :name, :schedule, presence: true
  validate :schedule_parses, if: :schedule?
  validate { errors.add(:folder, "must be a media folder") unless folder&.media? }
  validate { errors.add(:tag_ids, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.size }

  before_save(if: -> { schedule_changed? || auto_publish_changed? }) { self.next_run_at = next_occurrence }

  # The schedule as a cron, in config.time_zone unless it names a zone; Fugit would read a zoneless one in the host's.
  def cron
    parsed = Fugit.parse_cronish(schedule.to_s)
    parsed&.timezone ? parsed : Fugit.parse_cronish("#{schedule} #{Time.zone.tzinfo.name}")
  end

  def next_occurrence = cron&.next_time(Time.current)&.to_t&.in_time_zone

  def occurrences(range) = cron ? cron.within(range).map { it.to_t.in_time_zone } : []

  def tags = Tag.where(id: tag_ids).ordered

  # Where it posts from, e.g. "Ready / Stories #barber".
  def source = [ folder&.path, *tags.map { "##{it.name}" } ].compact.join(" ")

  # Media posted by any rubric count, so a photo isn't a story and a post on the same day.
  def next_media
    user.library_media.where(folder:).tagged_all(tag_ids).of_type(("video" if reel?)).where.associated(:file_attachment)
      .left_joins(:rubric_posts).group(:id)
      .order(Arel.sql("MAX(rubric_posts.scheduled_at) IS NOT NULL, MAX(rubric_posts.scheduled_at), library_media.id")).first
  end

  # Each of `rubrics`' times from now until `upto` as [time, rubric, media, fresh]: the media #next_media would pick then,
  # had every earlier time posted its pick; fresh if it was never posted. Times that already have a post are left out.
  # ponytail: assumes the folders don't change meanwhile.
  def self.plan(rubrics, upto)
    pool = LibraryMedia.where(user_id: rubrics.map(&:user_id), folder_id: rubrics.map(&:folder_id)).with_attached_file
      .includes(:tags).select { it.file.attached? }
    last = RubricPost.where(library_media: pool).group(:library_media_id).maximum(:scheduled_at)
    by_folder = pool.group_by { [ it.user_id, it.folder_id ] }
    taken = RubricPost.where(rubric_id: rubrics.map(&:id)).pluck(:rubric_id, :scheduled_at).to_set { |id, time| [ id, time.to_i ] }

    rubrics.flat_map { |rubric| rubric.occurrences(Time.current..upto).map { [ it, rubric ] } }
      .reject { |time, rubric| taken.include?([ rubric.id, time.to_i ]) }.sort_by(&:first).map do |time, rubric|
      media = by_folder.fetch([ rubric.user_id, rubric.folder_id ], [])
        .select { (!rubric.reel? || it.file.content_type.start_with?("video/")) && (rubric.tag_ids - it.tag_ids).empty? }
        .min_by { [ last[it.id] ? 1 : 0, last[it.id].to_i, it.id ] }
      fresh = media && !last[media.id]
      last[media.id] = time if media
      [ time, rubric, media, fresh ]
    end
  end

  # Advances first, so a failure never loops and missed times after downtime post once. A post already made for the due
  # time goes out instead of a new one.
  def run!
    due = next_run_at
    update!(next_run_at: next_occurrence)
    post = posts.find_by(scheduled_at: due) || next_media&.then { posts.create!(library_media: it) } or return
    PublishRubricPostJob.perform_later(post)
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
