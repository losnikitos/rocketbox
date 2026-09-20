# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "three" # @0.170.0 (full three.module.min.js — jspm stub is unusable under importmap)
pin "swiper" # @11.2.10 (full +esm bundle — jspm stub is unusable under importmap)
