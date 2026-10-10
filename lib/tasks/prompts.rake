# frozen_string_literal: true

namespace :prompts do
  desc "Upsert prompts by name from db/prompts.yml (new ones land in the default Shots folder)"
  task import: :environment do
    YAML.load_file(Rails.root.join("db/prompts.yml")).each do |entry|
      Prompt.find_or_initialize_by(name: entry["name"]).update!(body: entry["body"])
    end
    puts "#{Prompt.count} prompts"
  end
end
