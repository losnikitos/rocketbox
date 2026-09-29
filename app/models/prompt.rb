# frozen_string_literal: true

# LLM prompt bodies, looked up by key. Mirrored as prompts/<key>.md; see docs/PROMPTS.md.
class Prompt < ApplicationRecord
  DIR = Rails.root.join("prompts")

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :body, presence: true

  def self.body_for!(key)
    find_by!(key: key.to_s).body
  end

  def self.push
    DIR.glob("*.md").each { |path| find_or_initialize_by(key: path.basename(".md").to_s).update!(body: path.read.strip) }
  end

  def self.pull
    DIR.mkpath
    find_each { |prompt| DIR.join("#{prompt.key}.md").write("#{prompt.body}\n") }
  end
end
