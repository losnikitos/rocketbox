# frozen_string_literal: true

# Fresha's public booking-flow GraphQL API (no auth). Only persisted queries are accepted,
# so the hashes are tied to Fresha's frontend build and must be re-captured when they change.
module FreshaAvailability
  Error = Class.new(StandardError)

  URL = "https://www.fresha.com/graphql"
  SLUG = "wick-lane-barbershop-london-block-a-349-wick-lane-b46i79ki"
  INIT_HASH = "a7cfc9d847618480af2172d9efe47999a709d5e9ea0d8c8ae65c7770501fe4fb"
  ACTION_HASH = "305235d3fd9347f5451180a50060783f54df6dcdb371f739cb6d0bd2e0b17f31"
  SLOT_STEP = 15.minutes.to_i

  # Fresha rejects the Initialize mutation unless every option key is present.
  INIT_OPTIONS = {
    marketingToken: nil, cnToken: nil, via: nil, isGroupBooking: false, isRebook: false,
    rwgToken: nil, geiToken: nil, employeeId: nil, professionalProfileSlug: nil,
    shouldShowAllEmployees: false, isFromLinkBuilder: false, waitlistEntryToken: nil,
    firstTouchAt: nil, clientChannelType: "DIRECT", appointmentId: nil, giftCardCode: nil,
    offerItemId: nil, offerItems: nil, cartId: nil, providerReferences: [],
    preferredDate: nil, preferredTimeslot: nil, landingPageUrl: nil, externalReferrerUrl: nil
  }.freeze

  module_function

  # => { venue:, service:, fetched_at:, days: [ { date:, open:, available: ["09:00"], taken: ["11:00"] } ] }
  def fetch(days: 7)
    init = request!("BookingFlow_Initialize_Mutation", {
      input: { locationSlug: SLUG, configToken: nil, referer: "", options: INIT_OPTIONS,
               shouldAutoContinue: true, capabilities: %w[SERVICE_ADDONS CONFIRMATION] }
    }, INIT_HASH).fetch("bookingFlowInitialize")
    cart_id = init.fetch("cartId")
    services = init.fetch("screenServices")
    item = services.dig("categories", 0, "items", 0) || raise(Error, "Venue has no bookable services")

    press(cart_id, item.dig("secondaryAction", "id"))
    flow = press(cart_id, services.dig("continueAction", "id"))
    screen = flow["screenTime"] || raise(Error, "Booking flow did not reach the time screen")
    location_id = JSON.parse(screen.dig("continueAction", "id")).last

    {
      venue: flow.dig("layout", "cart", "name"),
      service: "#{item["name"].strip} (#{item["caption"]})",
      fetched_at: Time.current,
      days: screen.fetch("dates").first(days).map do |d|
        date = d.dig("date", "iso").first(10)
        next { date: date, open: false, available: [], taken: [] } unless d["isAvailableToBeBooked"]

        day = press(cart_id, [ { type: "onScreenTimeDaySelectorDateSet", date: date }, location_id ].to_json).dig("screenTime", "day")
        seconds = Array(day["timeslots"]).map { |t| JSON.parse(t.dig("action", "id")).first.fetch("time") }
        # ponytail: "taken" is gaps between the first and last open slot; the API has no opening hours,
        # so bookings at the very start/end of the day are missed. Upgrade: read the venue's opening hours.
        grid = seconds.any? ? (seconds.min..seconds.max).step(SLOT_STEP).to_a : []
        { date: date, open: true, available: seconds.map { hhmm(it) }, taken: (grid - seconds).map { hhmm(it) } }
      end
    }
  end

  # A half hour is taken if any 15-min slot in it is taken. => { "09:00" => :free, "09:30" => :taken }
  def half_hours(day)
    bucket = ->(time) { "#{time[0, 3]}#{time[3, 2].to_i < 30 ? "00" : "30"}" }
    day[:available].map(&bucket).index_with(:free).merge(day[:taken].map(&bucket).index_with(:taken)).sort.to_h
  end

  # Placeholder days in the `fetch` shape, for layers when no stored calendar covers the dates.
  def sample(from: Date.current, days: 3)
    times = (9 * 3600...19 * 3600).step(30.minutes.to_i).map { hhmm(it) }
    (from...from + days).map do |date|
      rng = Random.new(date.jd)
      taken, available = times.partition { rng.rand < 0.45 }
      { date: date.iso8601, open: true, available: available, taken: taken }
    end
  end

  def press(cart_id, action_id)
    request!("BookingFlow_ActionButtonPressed_Mutation",
      { id: action_id, cartId: cart_id, shouldAutoContinue: true }, ACTION_HASH).fetch("bookingFlowActionButtonPressed")
  end

  def request!(operation, variables, sha)
    response = connection.post("", {
      operationName: operation, variables: variables,
      extensions: { persistedQuery: { version: 1, sha256Hash: sha } }
    })
    body = response.body.is_a?(Hash) ? response.body : {}
    return body["data"] if response.success? && body["data"]

    raise Error, body.dig("errors", 0, "message").presence || "Fresha #{operation} failed (HTTP #{response.status})"
  end

  def hhmm(seconds)
    format("%02d:%02d", seconds / 3600, seconds % 3600 / 60)
  end

  def connection
    Faraday.new(url: URL, headers: { "x-client-platform" => "web", "User-Agent" => "Mozilla/5.0" }, request: { timeout: 30 }) do |f|
      f.request :json
      f.response :json
    end
  end
end
