# Runs every 15 minutes from config/recurring.yml (spec 4.1) and fans out one
# fetch job per feed, so a slow or broken feed does not hold up the others.
class FetchAllFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.select(:id).find_in_batches do |feeds|
      ActiveJob.perform_all_later(feeds.map { |feed| FetchFeedJob.new(feed) })
    end
  end
end
