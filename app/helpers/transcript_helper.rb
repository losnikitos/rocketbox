# frozen_string_literal: true

module TranscriptHelper
  def transcript_bubble(role)
    role.to_s == "system" ? "w-full" : "max-w-2xl"
  end

  def transcript_align(role)
    case role.to_s
    when "user" then "ml-auto w-fit max-w-2xl items-end"
    when "system" then "w-full"
    else "mr-auto w-fit max-w-2xl items-start"
    end
  end

  # Darker than the signal fills so the word stays readable on a white bubble.
  def transcript_role(role)
    case role.to_s
    when "system" then "text-[#8f6b00]"
    when "user" then "text-rocket"
    when "assistant" then "text-[#178247]"
    else "text-ink-500"
    end
  end

  def transcript_body(content)
    JSON.pretty_generate(JSON.parse(content.to_s))
  rescue JSON::ParserError, TypeError
    content.to_s
  end
end
