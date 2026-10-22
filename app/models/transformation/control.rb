# frozen_string_literal: true

# Steps that gate or steer the pipeline without transforming media (e.g. Approval, Sort).
class Transformation::Control < Transformation::Type
  def self.label = "Control"
end
