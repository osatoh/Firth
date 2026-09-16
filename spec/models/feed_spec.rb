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
end
