require "rails_helper"

RSpec.describe FetchFeedJob, type: :job do
  let(:feed) { create(:feed, url: "https://example.com/feed.xml") }
  let(:rss) { file_fixture("feed.rss").read }

  def stub_feed(body: rss, status: 200)
    stub_request(:get, feed.url).to_return(status:, body:)
  end

  it "stores the feed's entries as articles" do
    stub_feed

    described_class.perform_now(feed)

    expect(feed.articles.order(:published_at).pluck(:guid, :url, :title, :published_at)).to eq [
      [ "https://example.com/posts/1", "https://example.com/posts/1", "First Post", Time.utc(2026, 9, 21, 9) ],
      # An entry without a guid is identified by its URL.
      [ "https://example.com/posts/2", "https://example.com/posts/2", "Second Post", Time.utc(2026, 9, 22, 9) ]
    ]
  end

  it "skips entries that are already stored" do
    stub_feed
    create(:article, feed:, guid: "https://example.com/posts/1", title: "Stored earlier")

    expect { described_class.perform_now(feed) }.to change(feed.articles, :count).by(1)
    expect(feed.articles.find_by!(guid: "https://example.com/posts/1").title).to eq "Stored earlier"
  end

  it "stores nothing new when fetched twice" do
    stub_feed
    described_class.perform_now(feed)

    expect { described_class.perform_now(feed) }.not_to change(Article, :count)
  end

  it "records when the feed was fetched" do
    stub_feed

    freeze_time do
      described_class.perform_now(feed)

      expect(feed.reload.last_fetched_at).to eq Time.current
    end
  end

  it "follows a redirect" do
    stub_request(:get, feed.url).to_return(status: 301, headers: { "Location" => "https://example.com/new.xml" })
    stub_request(:get, "https://example.com/new.xml").to_return(status: 200, body: rss)

    expect { described_class.perform_now(feed) }.to change(feed.articles, :count).by(2)
  end

  it "skips entries without a URL" do
    stub_feed(body: rss.sub("<link>https://example.com/posts/2</link>", ""))

    expect { described_class.perform_now(feed) }.to change(feed.articles, :count).by(1)
  end

  # A broken feed is retried by the next scheduled fetch, not by re-raising.
  context "when the feed cannot be fetched" do
    [
      [ "the server returns an error", -> { stub_feed(status: 500) } ],
      [ "the body is not a feed", -> { stub_feed(body: "<html>not a feed</html>") } ],
      [ "the connection fails", -> { stub_request(:get, feed.url).to_raise(SocketError) } ],
      [ "the request times out", -> { stub_request(:get, feed.url).to_timeout } ]
    ].each do |situation, stub|
      it "stores nothing and does not raise when #{situation}" do
        instance_exec(&stub)

        expect { described_class.perform_now(feed) }.not_to raise_error
        expect(feed.articles).to be_empty
        expect(feed.reload.last_fetched_at).to be_nil
      end
    end
  end
end
