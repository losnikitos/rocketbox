# frozen_string_literal: true

namespace :shots do
  desc "Upsert shots by name from db/shots.yml"
  task import: :environment do
    YAML.load_file(Rails.root.join("db/shots.yml")).each do |entry|
      Shot.find_or_initialize_by(name: entry["name"]).update!(body: entry["body"])
    end
    puts "#{Shot.count} shots"
  end
end
