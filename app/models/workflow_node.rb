# frozen_string_literal: true

# A workflow's folder, media or transformation step, placed at x, y (its centre) on the canvas. A step owns its
# transformation, made from a type added from + Add, named after it, and deleted with the step.
# A folder's role comes from its edges: one feeding a step is an input, one a step feeds is an output.
# A folder with a tag holds only its media with that tag, and gives its `newest` media. A media is a source that always
# gives that one media.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow
  belongs_to :folder, optional: true
  belongs_to :library_media, optional: true
  belongs_to :transformation, optional: true, dependent: :destroy
  belongs_to :tag, optional: true
  accepts_nested_attributes_for :transformation

  before_validation { transformation.name = transformation.type&.label if transformation&.new_record? && transformation.name.blank? }
  validate { errors.add(:base, "Pick a folder, a media or a transformation.") unless [ folder, library_media, transformation ].compact.one? }
  validate { errors.add(:tag, "only filters a folder") if tag && !folder }
  validates :newest, numericality: { only_integer: true, greater_than: 0 }

  def step? = transformation_id.present?

  def label
    if step? then transformation&.name
    elsif (media = library_media) then media.file.attached? ? media.file.filename.to_s : media.kind.humanize
    else [ folder&.path, tag && "##{tag.name}", ("· newest #{newest}" if newest.to_i > 1) ].compact.join(" ")
    end
  end
end
