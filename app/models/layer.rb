# frozen_string_literal: true

# Overlay template defined in code (ERB + Tailwind under app/views/accounts/layers/templates),
# rendered to a transparent PNG to compose SMM posts with.
class Layer
  Field = Data.define(:name, :label, :type, :default) do
    def value(raw)
      raw = raw.is_a?(String) ? raw.presence : nil
      raw = (Date.iso8601(raw) rescue nil) if raw && type == :date
      raw = raw[/\A#\h{6}\z/] if raw && type == :color
      raw = raw[%r{\A(https://|data:image/)\S+\z}] if raw && type == :url
      raw || (default.respond_to?(:call) ? default.call : default)
    end
  end

  attr_reader :slug, :name, :size, :fields

  def initialize(slug:, name:, size:, fields:)
    @slug, @name, @size, @fields = slug, name, size, fields
  end

  ALL = [
    new(slug: "fully-booked", name: "Fully booked", size: [ 1080, 1920 ], fields: [
      Field.new(:headline, "Text", :text, "Fully Booked"),
      Field.new(:date, "Date", :date, -> { Date.current })
    ]),
    new(slug: "fully-booked-color", name: "Fully booked (color)", size: [ 1080, 1920 ], fields: [
      Field.new(:headline, "Text", :text, "Fully Booked"),
      Field.new(:caption, "Caption", :text, "Thanks for keeping us busy"),
      Field.new(:date, "Date", :date, -> { Date.current }),
      Field.new(:accent, "Accent", :color, "#ebcb9f"),
      Field.new(:panel, "Panel", :color, "#18181b")
    ]),
    new(slug: "daily", name: "Daily", size: [ 1080, 1920 ], fields: [
      Field.new(:time, "Time", :text, "09:45"),
      Field.new(:caption, "Caption", :text, "first clients")
    ]),
    new(slug: "review", name: "Review", size: [ 1080, 1920 ], fields: [
      Field.new(:text, "Review", :text, "Friendly, fast, and exactly what I asked for. Already booked my next visit."),
      Field.new(:name, "Customer", :text, "Alex M."),
      Field.new(:photo, "Photo URL", :url, nil)
    ])
  ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def self.screenshot(html, size:)
    # ponytail: boots a fresh Chrome per render (~1s); keep a long-lived browser if renders become frequent.
    browser = Ferrum::Browser.new(browser_options: { "no-sandbox": nil })
    browser.set_viewport(width: size.first, height: size.last, scale_factor: 1)
    browser.content = html
    browser.network.wait_for_idle
    browser.screenshot(format: "png", encoding: :binary, background_color: Ferrum::RGBA.new(0, 0, 0, 0.0))
  ensure
    browser&.quit
  end

  def to_param = slug

  def template = "accounts/layers/templates/#{slug.underscore}"

  def values(params = {})
    fields.to_h { [ it.name, it.value(params[it.name]) ] }
  end
end
