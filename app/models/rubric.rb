# frozen_string_literal: true

# A recurring series of Instagram posts, e.g. "a story from ready/stories every weekday at 9am". When auto-publish is on,
# each scheduled time publishes a media of the folder no rubric has posted yet as one RubricPost, from the least-posted
# job first, then the oldest, and skips once there's none; otherwise the rubric only shows on the Schedule calendar.
# With tags, it only takes the folder's media with all of them.
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

  # A media no rubric has posted (or scheduled) yet, so a photo is never both a story and a post, from the least-posted
  # job first (none counts as 0), then the oldest; nil once there's none.
  def next_media
    user.library_media.where(folder:).tagged_all(tag_ids).of_type(("video" if reel?)).where.associated(:file_attachment)
      .where.missing(:rubric_posts).left_joins(:job).order(Arel.sql("COALESCE(jobs.posts_count, 0)"), :id).first
  end

  # Each of `rubrics`' times from now until `upto` as [time, rubric, media]: the media #next_media would pick then, had
  # every earlier time posted its pick; nil once nothing fresh is left. Times that already have a post are left out.
  # ponytail: assumes the folders don't change meanwhile.
  def self.plan(rubrics, upto)
    pool = LibraryMedia.where(user_id: rubrics.map(&:user_id), folder_id: rubrics.map(&:folder_id)).with_attached_file
      .includes(:tags, :job).select { it.file.attached? }.sort_by(&:id)
    posted = RubricPost.where(library_media: pool).distinct.pluck(:library_media_id).to_set
    uses = pool.filter_map(&:job).to_h { [ it.id, it.posts_count ] }
    by_folder = pool.group_by { [ it.user_id, it.folder_id ] }
    taken = RubricPost.where(rubric_id: rubrics.map(&:id)).pluck(:rubric_id, :scheduled_at).to_set { |id, time| [ id, time.to_i ] }

    rubrics.flat_map { |rubric| rubric.occurrences(Time.current..upto).map { [ it, rubric ] } }
      .reject { |time, rubric| taken.include?([ rubric.id, time.to_i ]) }.sort_by(&:first).map do |time, rubric|
      media = by_folder.fetch([ rubric.user_id, rubric.folder_id ], []).select do
        !posted.include?(it.id) && (!rubric.reel? || it.file.content_type.start_with?("video/")) && (rubric.tag_ids - it.tag_ids).empty?
      end.min_by { [ uses.fetch(it.job_id, 0), it.id ] }
      posted << media.id if media
      uses[media.job_id] += 1 if media&.job_id
      [ time, rubric, media ]
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
