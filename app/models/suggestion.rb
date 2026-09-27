# frozen_string_literal: true

class Suggestion < ApplicationRecord
  MEDIA_KEYS = %w[photo video].freeze

  belongs_to :crawl
  delegate :user, to: :crawl

  enum :status, %w[pending applied rejected].index_by(&:itself)

  validates :key, inclusion: { in: Crawl::FIELDS.keys + %w[logo] + MEDIA_KEYS }
  validates :value, presence: true

  scope :media, -> { where(key: MEDIA_KEYS) }
  scope :business, -> { where.not(key: MEDIA_KEYS) }

  def media?
    key.in?(MEDIA_KEYS)
  end

  # Raises RemoteFile::Error when the logo, photo, or video can't be downloaded; the status is left as is.
  def apply!
    case key
    when "logo"
      io = RemoteFile.fetch(value)
      raise RemoteFile::Error, "#{io.content_type} is not an image." unless io.content_type.start_with?("image/")

      user.logo.attach(io: io, filename: RemoteFile.filename(value), content_type: io.content_type)
    when *MEDIA_KEYS
      user.library_media.import_url!(value)
    else
      user.update!(Crawl::FIELDS.fetch(key) => value)
    end
    applied!
  end
end
