# frozen_string_literal: true

require "open-uri"

namespace :styles do
  desc "Upsert styles by name from db/styles.yml (exported from tadaaa shooting styles); photos only for styles without examples"
  task import: :environment do
    YAML.load_file(Rails.root.join("db/styles.yml")).each do |entry|
      style = Style.find_or_initialize_by(name: entry["name"])
      style.body = entry["body"]
      if style.examples.blank?
        style.examples = entry["photos"].each_with_index.map do |url, index|
          io = URI.open(url)
          { io:, content_type: io.content_type, filename: "#{entry["name"].parameterize}-#{index + 1}#{Rack::Mime::MIME_TYPES.invert[io.content_type]}" }
        end
      end
      style.save!
      puts "#{style.name}: #{style.examples.size} examples"
    end
  end
end
