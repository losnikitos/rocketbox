# frozen_string_literal: true

class CrawlBusinessJob < ApplicationJob
  queue_as :default

  def perform(crawl_id)
    CrawlBusiness.call(crawl: Crawl.find(crawl_id))
  end
end
