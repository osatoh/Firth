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

  it "skips entries whose URL is not http(s)" do
    stub_feed(body: rss.sub("<link>https://example.com/posts/2</link>", "<link>javascript:alert(1)</link>"))

    described_class.perform_now(feed)

    expect(feed.articles.pluck(:url)).to eq [ "https://example.com/posts/1" ]
  end

  # A broken feed is retried by the next scheduled fetch, not by re-raising.
  context "when the feed cannot be fetched" do
    [
      [ "the server returns an error", -> { stub_feed(status: 500) } ],
      [ "the body is not a feed", -> { stub_feed(body: "<html>not a feed</html>") } ],
      [ "the connection fails", -> { stub_request(:get, feed.url).to_raise(SocketError) } ],
      [ "the request times out", -> { stub_request(:get, feed.url).to_timeout } ],
      [ "the host resolves to a private address", -> { allow(Resolv).to receive(:getaddresses).and_return([ "127.0.0.1" ]) } ],
      [ "it redirects to a private address", lambda {
        stub_request(:get, feed.url).to_return(status: 302, headers: { "Location" => "http://169.254.169.254/" })
        allow(Resolv).to receive(:getaddresses).and_call_original
        allow(Resolv).to receive(:getaddresses).with("example.com").and_return([ "93.184.215.14" ])
      } ]
    ].each do |situation, stub|
      it "stores nothing and does not raise when #{situation}" do
        instance_exec(&stub)

        expect { described_class.perform_now(feed) }.not_to raise_error
        expect(feed.articles).to be_empty
        expect(feed.reload.last_fetched_at).to be_nil
      end
    end
  end

  it "is discarded when its user deleted the account before it ran" do
    serialized = described_class.new(feed).serialize
    feed.user.destroy!

    expect { ActiveJob::Base.execute(serialized) }.not_to raise_error
    expect(WebMock).not_to have_requested(:any, //)
  end

  context "when its user deletes the account while it runs" do
    # The failing insert aborts the surrounding transaction, which a
    # transactional test would then be stuck in.
    self.use_transactional_tests = false

    after { User.where(id: feed.user_id).delete_all }

    it "does nothing" do
      stub_request(:get, feed.url).to_return do
        feed.user.destroy!
        { body: rss }
      end

      expect { described_class.perform_now(feed) }.not_to raise_error
      expect(Article.where(feed_id: feed.id)).to be_empty
    end
  end
end
