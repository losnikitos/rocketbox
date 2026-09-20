# frozen_string_literal: true

class PricingController < ApplicationController
  TIERS = [
    {
      name: "Starter",
      price: "£29",
      blurb: "Keep the feed alive",
      highlighted: false,
      features: [
        "Up to 8 feed posts per month",
        "Telegram media intake",
        "Captions & hashtags",
        "Delete after publish"
      ]
    },
    {
      name: "Pro",
      price: "£59",
      blurb: "Full Instagram cadence",
      highlighted: true,
      features: [
        "Up to 20 posts per month (feed + Reels)",
        "Stories included",
        "Telegram media intake",
        "Captions & hashtags",
        "Delete after publish",
        "Google Maps photos"
      ]
    },
    {
      name: "Growth",
      price: "£119",
      blurb: "Max output + extras",
      highlighted: false,
      features: [
        "Daily posting (feed + Reels)",
        "Stories included",
        "Telegram media intake",
        "Captions & hashtags",
        "Delete after publish",
        "Google Maps photos",
        "Printed contact cards",
        "Priority onboarding"
      ]
    }
  ].freeze

  def show
  end
end
