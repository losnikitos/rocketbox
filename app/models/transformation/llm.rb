# frozen_string_literal: true

# Writes one prompt: the step's prompt is the instruction, the input prompts and images the message.
# ponytail: always RubyLLM's default chat model (config/initializers/ruby_llm.rb). Upgrade = a model option from the
# chat models enabled in Active Admin.
class Transformation::Llm < Transformation::Generation
  def self.label = "LLM"

  def self.description = "Writes one prompt from the prompts and images fed to it, or from its instruction alone."

  def self.inputs = { prompt: 0.., image: 0.. }

  def self.makes = :prompt

  def self.options = {}

  def body
    chat = RubyLLM.chat.with_instructions("#{run.prompt_text}\n\nReply with the new prompt's text only.")
    message = source_prompts.map { "## #{it.name}\n\n#{it.body}" }.join("\n\n").presence || "Write it."
    reply = chat.ask(message, with: source_media.map(&:file))
    run.cost = chat.cost.total
    reply.content.to_s.strip.presence || raise("The model wrote nothing.")
  end

  private

    def source_prompts = run.sources.grep(Prompt)
end
