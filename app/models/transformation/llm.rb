# frozen_string_literal: true

# Writes one prompt from its input prompts: the step's prompt is the instruction, the input prompts the message.
# ponytail: always RubyLLM's default chat model (config/initializers/ruby_llm.rb). Upgrade = a model option from the
# chat models enabled in Active Admin.
class Transformation::Llm < Transformation::Generation
  def self.label = "LLM"

  def self.description = "Writes one prompt from the prompts fed to it."

  def self.takes = %i[prompt]

  def self.makes = :prompt

  def self.options = {}

  def body
    chat = RubyLLM.chat.with_instructions("#{run.prompt_text}\n\nReply with the new prompt's text only.")
    reply = chat.ask(source_prompts.map { "## #{it.name}\n\n#{it.body}" }.join("\n\n"))
    run.cost = chat.cost.total
    reply.content.to_s.strip.presence || raise("The model wrote nothing.")
  end

  private

    def source_prompts = run.sources.grep(Prompt)
end
