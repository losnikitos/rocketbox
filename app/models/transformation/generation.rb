# frozen_string_literal: true

# One AI call on the source media, prompted by the run's prompt text, with the run's options.
class Transformation::Generation < Transformation::Type
  def self.label = "Generation"

  def self.ai? = true

  def self.inputs = nil

  private

    def images = source_media.map { it.file.blob }

    def ai_args
      opts = run.ai_options
      { model: opts[:model], provider: opts[:provider], provider_options: opts.except(:provider, :model) }
    end
end
