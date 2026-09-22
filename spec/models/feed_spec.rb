require "rails_helper"

RSpec.describe Feed, type: :model do
  describe "validations" do
    it "is valid with a title and an http/https URL" do
      expect(build(:feed, title: "Example Blog", url: "https://example.com/feed.xml")).to be_valid
      expect(build(:feed, url: "http://example.com/feed.xml")).to be_valid
    end

    it "is invalid without a title" do
      feed = build(:feed, title: "")

      expect(feed).to be_invalid
      expect(feed.errors).to be_of_kind(:title, :blank)
    end

    it "is invalid without a URL" do
      feed = build(:feed, url: "")

      expect(feed).to be_invalid
      expect(feed.errors).to be_of_kind(:url, :blank)
    end

    # The "invalid URLs are rejected" half of task 2.1: anything that is not
    # an http/https URL, or that cannot be read as a URL at all.
    [
      "ftp://example.com/feed.xml",
      "javascript:alert(1)",
      "example.com/feed.xml",
      "https://",
      "not a url",
      "http://例 えば.com"
    ].each do |invalid_url|
      it "is invalid when the URL is #{invalid_url.inspect}" do
        feed = build(:feed, url: invalid_url)

        expect(feed).to be_invalid
        expect(feed.errors).to be_of_kind(:url, :invalid)
      end
    end

    it "rejects a URL the same user has already registered" do
      user = create(:user)
      create(:feed, user:, url: "https://example.com/feed.xml")

      feed = build(:feed, user:, url: "https://example.com/feed.xml")

      expect(feed).to be_invalid
      expect(feed.errors).to be_of_kind(:url, :taken)
    end

    # RFC 3986: the scheme and host are case-insensitive, and for http(s)
    # an empty path is equivalent to "/".
    it "treats a URL that differs only by scheme or host case as a duplicate" do
      user = create(:user)
      create(:feed, user:, url: "https://example.com/feed.xml")

      feed = build(:feed, user:, url: "HTTPS://EXAMPLE.com/feed.xml")

      expect(feed).to be_invalid
      expect(feed.errors).to be_of_kind(:url, :taken)
    end

    it "treats an empty path and \"/\" as the same URL" do
      user = create(:user)
      create(:feed, user:, url: "https://example.com")

      feed = build(:feed, user:, url: "https://example.com/")

      expect(feed).to be_invalid
      expect(feed.errors).to be_of_kind(:url, :taken)
    end

    it "stores the normalized URL" do
      feed = create(:feed, url: "HTTPS://EXAMPLE.com")

      expect(feed.url).to eq("https://example.com/")
    end

    it "keeps the path as given, since paths are case-sensitive" do
      feed = create(:feed, url: "https://example.com/Feed.xml")

      expect(feed.url).to eq("https://example.com/Feed.xml")
    end

    it "allows another user to register the same URL" do
      create(:feed, url: "https://example.com/feed.xml")

      expect(build(:feed, url: "https://example.com/feed.xml")).to be_valid
    end
  end

  describe "ownership" do
    it "is destroyed along with its user" do
      feed = create(:feed)

      expect { feed.user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "fetching" do
    it "enqueues a fetch as soon as the feed is created" do
      feed = create(:feed)

      expect(FetchFeedJob).to have_been_enqueued.with(feed)
    end

    it "enqueues a fetch when the URL changes" do
      feed = create(:feed, url: "https://example.com/feed.xml")
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      feed.update!(url: "https://example.com/other.xml")

      expect(FetchFeedJob).to have_been_enqueued.with(feed)
    end

    it "does not enqueue a fetch when only the title changes" do
      feed = create(:feed)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      feed.update!(title: "Renamed")

      expect(FetchFeedJob).not_to have_been_enqueued
    end
  end
end
