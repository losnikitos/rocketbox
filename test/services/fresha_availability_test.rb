# frozen_string_literal: true

require "test_helper"

class FreshaAvailabilityTest < ActiveSupport::TestCase
  setup { @original = FreshaAvailability.method(:request!) }
  teardown { FreshaAvailability.define_singleton_method(:request!, @original) }

  test "builds days with available slots and gaps as taken" do
    slot = ->(seconds) { { "action" => { "id" => [ { type: "onScreenTimeSet", date: "2026-10-05", time: seconds }, "42" ].to_json } } }
    FreshaAvailability.define_singleton_method(:request!) do |operation, variables, _sha|
      next { "bookingFlowInitialize" => { "cartId" => "c1", "screenServices" => {
        "continueAction" => { "id" => "continue" },
        "categories" => [ { "items" => [ { "name" => "Dry Haircut ", "caption" => "30 mins", "secondaryAction" => { "id" => "add" } } ] } ]
      } } } if operation == "BookingFlow_Initialize_Mutation"

      pressed = case variables[:id]
      when "add" then {}
      when "continue" then { "layout" => { "cart" => { "name" => "Wick Lane Barbershop" } }, "screenTime" => {
        "continueAction" => { "id" => [ { type: "onScreenTimeContinue" }, "42" ].to_json },
        "dates" => [
          { "date" => { "iso" => "2026-10-04T00:00:00.000Z" }, "isAvailableToBeBooked" => false },
          { "date" => { "iso" => "2026-10-05T00:00:00.000Z" }, "isAvailableToBeBooked" => true }
        ]
      } }
      when [ { type: "onScreenTimeDaySelectorDateSet", date: "2026-10-05" }, "42" ].to_json
        { "screenTime" => { "day" => { "timeslots" => [ 32400, 33300, 35100 ].map(&slot) } } }
      else raise "unexpected action #{variables[:id]}"
      end
      { "bookingFlowActionButtonPressed" => pressed }
    end

    calendar = FreshaAvailability.fetch

    assert_equal [ "Wick Lane Barbershop", "Dry Haircut (30 mins)" ], [ calendar[:venue], calendar[:service] ]
    assert_equal [
      { date: "2026-10-04", open: false, available: [], taken: [] },
      { date: "2026-10-05", open: true, available: %w[09:00 09:15 09:45], taken: %w[09:30] }
    ], calendar[:days]
  end

  test "half hours are taken if any 15-min slot in them is taken" do
    assert_equal({ "09:00" => :free, "09:30" => :taken, "10:00" => :free },
      FreshaAvailability.half_hours(available: %w[09:00 09:15 10:00], taken: %w[09:45]))
  end
end
