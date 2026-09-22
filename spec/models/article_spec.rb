require "rails_helper"

RSpec.describe Article, type: :model do
  describe "validations" do
    it "is valid with a guid, URL and title" do
      expect(build(:article)).to be_valid
    end

    it "is invalid without a guid, URL or title" do
      article = build(:article, guid: "", url: "", title: "")

      expect(article).to be_invalid
      expect(article.errors).to be_of_kind(:guid, :blank)
      expect(article.errors).to be_of_kind(:url, :blank)
      expect(article.errors).to be_of_kind(:title, :blank)
    end

    it "is invalid when the feed already has an article with the same guid" do
      existing = create(:article)

      article = build(:article, feed: existing.feed, guid: existing.guid)

      expect(article).to be_invalid
      expect(article.errors).to be_of_kind(:guid, :taken)
    end

    it "allows the same guid in another feed" do
      existing = create(:article)

      expect(build(:article, guid: existing.guid)).to be_valid
    end
  end

  it "is deleted with its feed" do
    article = create(:article)

    expect { article.feed.destroy }.to change(Article, :count).by(-1)
  end

  describe "#mark_read!" do
    it "records when an unread article was read" do
      article = create(:article)

      expect { article.mark_read! }.to change(article, :read?).from(false).to(true)
    end

    it "keeps the first read time" do
      read_at = 1.day.ago.change(usec: 0)
      article = create(:article, read_at:)

      article.mark_read!

      expect(article.reload.read_at).to eq(read_at)
    end
  end
end
