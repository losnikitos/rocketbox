# Active Admin v3 SCSS → Propshaft-served CSS (avoids sassc-rails breaking Tailwind).
Rails.application.config.dartsass.builds = {
  "active_admin.scss" => "active_admin.css"
}

# Load Active Admin's Sass partials from the gem.
Rails.application.config.dartsass.build_options << "--load-path=#{Gem.loaded_specs["activeadmin"].full_gem_path}/app/assets/stylesheets"
Rails.application.config.dartsass.build_options << "--quiet-deps"
Rails.application.config.dartsass.build_options << "--silence-deprecation=import"
Rails.application.config.dartsass.build_options << "--silence-deprecation=global-builtin"
Rails.application.config.dartsass.build_options << "--silence-deprecation=color-functions"
