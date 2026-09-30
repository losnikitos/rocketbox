# frozen_string_literal: true

# How a recipe makes a post. Subclasses declare steps in run order; each step runs a node class
# (Workflow::Input, AiImage, …) on the outputs of the steps named in `from:`. Many recipes share a workflow;
# each fills in its own prompt and texts (Recipe#params_for).
#
#   class TwoPhotoStory < Workflow
#     step :photo_1, Input, slot: 1
#     step :film_1, AiImage, from: :photo_1
#     step :story, Output, from: :film_1, format: "story"
#   end
class Workflow
  Error = Class.new(StandardError)
  Step = Data.define(:key, :node, :from, :params)

  class << self
    def all
      Rails.root.glob("app/workflows/*.rb").map { it.basename(".rb").to_s.camelize.constantize } - [ Workflow ]
    end

    def steps
      @steps ||= []
    end

    def step(key, node, from: [], **params)
      from = Array(from).map(&:to_s)
      unknown = from - steps.map(&:key)
      raise ArgumentError, "#{name}##{key}: unknown step #{unknown.join(", ")} in from:" if unknown.any?

      steps << Step.new(key.to_s, node, from, params.stringify_keys)
    end

    def [](key)
      steps.find { it.key == key.to_s }
    end

    def text_steps
      steps.select { it.node == TextOverlay }
    end

    def format
      steps.find { it.node == Output }&.params&.dig("format")
    end

    # nil when an input takes every selected image.
    def input_count
      inputs = steps.select { it.node == Input }
      inputs.size unless inputs.any? { it.params["slot"].to_s == "all" }
    end

    # The step and every step that depends on it, in run order.
    def downstream(key)
      steps.each_with_object([ key.to_s ]) { |s, keys| keys << s.key if s.from.intersect?(keys) }
    end

    # Steps grouped by distance from the inputs, for the schematic.
    def columns
      depth = {}
      steps.each { |s| depth[s.key] = s.from.map { |k| depth[k] + 1 }.max || 0 }
      steps.group_by { depth[it.key] }.values
    end
  end
end
