require "rails_helper"

RSpec.describe OpmlImport do
  let(:user) { create(:user) }

  def import(name)
    OpmlImport.new(user:, io: file_fixture("opml/#{name}").open).call
  end

  it "creates the feeds of nested outlines, falling back to the host for the title" do
    result = import("subscriptions.opml")

    expect(user.feeds.order(:url).pluck(:title, :url)).to eq([
      [ "Example Blog", "https://example.com/feed.xml" ],
      [ "Text Only", "https://text.example.org/rss" ],
      [ "untitled.example.net", "https://untitled.example.net/atom.xml" ]
    ])
    expect(result).to have_attributes(added: 3, duplicate: 0, invalid: 1, over_limit: 0)
  end

  it "enqueues a fetch for each created feed" do
    expect { import("subscriptions.opml") }.to have_enqueued_job(FetchFeedJob).exactly(3).times
  end

  it "skips feeds already registered, even under another spelling" do
    create(:feed, user:, url: "https://EXAMPLE.com/feed.xml")

    result = import("subscriptions.opml")

    expect(result).to have_attributes(added: 2, duplicate: 1, invalid: 1, over_limit: 0)
  end

  it "counts a feed that loses a race at the unique index as a duplicate" do
    create(:feed, user:, url: "https://example.com/feed.xml")
    allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)

    result = import("subscriptions.opml")

    expect(result).to have_attributes(added: 2, duplicate: 1, invalid: 1, over_limit: 0)
  end

  it "stops at the feed limit and counts the rest" do
    stub_const("Feed::LIMIT_PER_USER", 2)
    create(:feed, user:)

    result = import("subscriptions.opml")

    expect(user.feeds.count).to eq(2)
    expect(result).to have_attributes(added: 1, over_limit: 3)
  end

  it "refuses external entities instead of loading them" do
    expect { import("xxe.opml") }.to raise_error(OpmlImport::InvalidFile)
    expect(user.feeds).to be_empty
  end

  it "rejects input over the size cap" do
    stub_const("OpmlImport::MAX_BYTES", 10)

    expect { import("subscriptions.opml") }.to raise_error(OpmlImport::TooLarge)
  end

  it "rejects input that is not OPML" do
    expect { import("not_xml.txt") }.to raise_error(OpmlImport::InvalidFile)
  end
end
