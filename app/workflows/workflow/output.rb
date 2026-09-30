# frozen_string_literal: true

class Workflow
  # Hands incoming media to the subject (post slides, or a generation's library media), in `from:` order.
  class Output
    LABEL = "Output"
    ICON = "paper-airplane"
    SCHEME = [].freeze # the format badge already names the output

    def self.call(inputs:, params:, run:)
      run.subject.store_output!(inputs, params["format"])
    end
  end
end
