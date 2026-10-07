# frozen_string_literal: true

# Each scripted recipe type is one folder under reels/ (see RecipeType::Scripted): reels/doppler/doppler.rb is
# Reels::Doppler, next to its original reel, track, cut ends and notebook.
module Reels; end

Rails.autoloaders.main.push_dir(Rails.root.join("reels"), namespace: Reels)
Rails.autoloaders.main.collapse(Rails.root.join("reels/*"))
