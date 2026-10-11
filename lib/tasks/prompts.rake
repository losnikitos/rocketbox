# frozen_string_literal: true

namespace :prompts do
  desc "Upsert prompts by name from db/prompts.yml (new ones land in prompts/shots)"
  task import: :environment do
    shots = Folder.prompts.children.find_or_create_by!(slug: "shots") { it.name = "Shots" }
    YAML.load_file(Rails.root.join("db/prompts.yml")).each do |entry|
      Prompt.find_or_initialize_by(name: entry["name"]) { it.folder = shots }.update!(body: entry["body"])
    end
    puts "#{Prompt.count} prompts"
  end
end
