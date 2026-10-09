# frozen_string_literal: true

# A workflow's folder, media, transformation step or note, placed at x, y (its centre) on the canvas. A step owns its
# transformation, made from a type added from + Add, named after it, and deleted with the step.
# A folder's role comes from its edges: one feeding a step is an input, one a step feeds is an output.
# A folder's tags filter what it gives, as an input, to its media with all of them, and are added, as an output, to what
# lands in it; it gives its `newest` media. A media is a source that always gives that one media.
# A note is a sticky note (Markdown, may be blank) in its `color`: it never connects, so runs pass it by.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow
  belongs_to :folder, optional: true
  belongs_to :library_media, optional: true
  belongs_to :transformation, optional: true, dependent: :destroy
  accepts_nested_attributes_for :transformation

  normalizes :tag_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq }

  before_validation { transformation.name = transformation.type&.label if transformation&.new_record? && transformation.name.blank? }
  validate { errors.add(:base, "Pick a folder, a media, a transformation or a note.") unless [ folder, library_media, transformation, note ].compact.one? }
  validate { errors.add(:tag_ids, "only go on a folder") if tag_ids.any? && !folder }
  validate { errors.add(:tag_ids, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.size }
  validates :newest, numericality: { only_integer: true, greater_than: 0 }
  validates :color, inclusion: { in: Folder.colors.keys }

  def step? = transformation_id.present?

  def note? = !note.nil?

  def tags = Tag.where(id: tag_ids).ordered

  # Whether `media` is in this folder with all its tags.
  def takes?(media) = folder_id.present? && folder_id == media.folder_id && (tag_ids - media.tag_ids).empty?

  def label
    if step? then transformation&.name
    elsif note? then note.lines.first&.strip.presence || "Note"
    elsif (media = library_media) then media.file.attached? ? media.file.filename.to_s : media.kind.humanize
    else [ folder&.path, *tags.map { "##{it.name}" }, ("· newest #{newest}" if newest.to_i > 1) ].compact.join(" ")
    end
  end
end
