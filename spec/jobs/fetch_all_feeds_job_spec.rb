require "rails_helper"

RSpec.describe FetchAllFeedsJob, type: :job do
  it "enqueues a fetch job for every feed" do
    feeds = create_list(:feed, 2)
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    described_class.perform_now

    feeds.each { |feed| expect(FetchFeedJob).to have_been_enqueued.with(feed) }
    expect(FetchFeedJob).to have_been_enqueued.exactly(2).times
  end

  it "is scheduled in the recurring config" do
    recurring = Rails.application.config_for(:recurring, env: "production")

    expect(recurring[:fetch_all_feeds]).to include(class: "FetchAllFeedsJob", schedule: "every 15 minutes")
  end
end
