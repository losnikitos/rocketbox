# frozen_string_literal: true

# A workflow's folder, media, transformation step or note, placed at x, y (its centre) on the canvas. A step owns its
# transformation, made from a type added from + Add, named after it, and deleted with the step.
# Every node but a note gives items of one kind (`item_kind`): a folder its kind's (media, prompts or reviews), a media
# itself, a step what its type makes. A folder's role comes from its edges: one feeding a step is an input, one a step
# feeds is an output.
# A folder gives its pinned items (`pinned_ids`, every run until reset), else its newest `take` of its items (and its
# subfolders' when `include_subfolders`, the default): a media folder's media, a prompt folder's prompts, Reviews'
# 5-star reviews. A media folder's tags filter what it gives to its media with all of them, and its `media_type` (nil
# for any) to images or videos. A step's tags go on what it makes.
# A note is a sticky note (Markdown, may be blank) in its `color`: it never connects, so runs pass it by.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow, touch: true
  belongs_to :folder, optional: true
  belongs_to :library_media, optional: true
  belongs_to :transformation, optional: true, dependent: :destroy
  accepts_nested_attributes_for :transformation

  normalizes :tag_ids, :pinned_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq }
  normalizes :media_type, with: -> { it.presence }

  before_validation { transformation.name = transformation.type&.label if transformation&.new_record? && transformation.name.blank? }
  validate { errors.add(:base, "Pick a folder, a media, a transformation or a note.") unless [ folder, library_media, transformation, note ].compact.one? }
  validate { errors.add(:tag_ids, "only go on a media folder or a step") if tag_ids.any? && !media_folder? && !transformation }
  validate { errors.add(:tag_ids, "include an unknown tag") unless Tag.where(id: tag_ids).count == tag_ids.size }
  validates :take, numericality: { only_integer: true, greater_than: 0 }
  validates :media_type, inclusion: { in: %w[image video] }, allow_nil: true
  validates :color, inclusion: { in: Folder.colors.keys }

  def step? = transformation_id.present?

  def note? = !note.nil?

  def media_folder? = !!folder&.media?

  # The kind of items it gives: :media, :prompt or :review; nil for a note.
  def item_kind
    if step? then transformation&.makes
    elsif folder then folder.kind.to_sym
    elsif library_media then :media
    end
  end

  def tags = Tag.where(id: tag_ids).ordered

  # Folder ids this node reads: itself, plus children when `include_subfolders`.
  def folder_ids = folder && (include_subfolders? ? folder.tree_ids : [ folder.id ])

  # Whether `media` is in this folder (or a subfolder when included), with all its tags, of its media type.
  def takes?(media)
    !!folder_ids&.include?(media.folder_id) && (tag_ids - media.tag_ids).empty? &&
      (media_type.nil? || (media_type == "image" ? media.story_image? : media.video?))
  end

  # A folder's media type and how many it gives, e.g. "Videos · take 3".
  def gives
    return unless folder
    [ media_type&.pluralize&.capitalize, pinned_ids.any? ? "#{pinned_ids.size} pinned" : ("take #{take}" if take.to_i > 1),
      ("this folder only" unless include_subfolders?) ].compact.join(" · ").presence
  end

  def label
    if step? then transformation&.name
    elsif note? then note.lines.first&.strip.presence || "Note"
    elsif (media = library_media) then media.file.attached? ? media.file.filename.to_s : media.kind.humanize
    else [ folder&.path, *tags.map { "##{it.name}" }, ("· #{gives}" if gives) ].compact.join(" ")
    end
  end
end
