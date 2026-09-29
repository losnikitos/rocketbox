namespace :prompts do
  desc "Upsert prompts/*.md into the Prompt table"
  task push: :environment do
    Prompt.push
  end

  desc "Write every Prompt row to prompts/<key>.md"
  task pull: :environment do
    Prompt.pull
  end
end
