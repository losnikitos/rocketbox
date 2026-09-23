# frozen_string_literal: true

# Build Active Admin's Sprockets-era JS into Propshaft's builds/ folder.
# ponytail: one-shot Sprockets compile; drop if we ever move to AA v4 (Tailwind/importmap).
namespace :active_admin do
  desc "Compile active_admin.js into app/assets/builds"
  task build_js: :environment do
    require "sprockets"

    env = Sprockets::Environment.new
    env.append_path Rails.root.join("app/assets/javascripts")
    Gem.loaded_specs.each_value do |spec|
      %w[app/assets/javascripts vendor/assets/javascripts lib/assets/javascripts].each do |subdir|
        path = File.join(spec.full_gem_path, subdir)
        env.append_path(path) if File.directory?(path)
      end
    end

    out = Rails.root.join("app/assets/builds/active_admin.js")
    out.write(env["active_admin.js"].to_s)
    puts "Wrote #{out} (#{out.size} bytes)" unless Rails.env.test?
  end
end

%w[assets:precompile test:prepare].each do |task_name|
  if Rake::Task.task_defined?(task_name)
    Rake::Task[task_name].enhance([ "active_admin:build_js" ])
  end
end
