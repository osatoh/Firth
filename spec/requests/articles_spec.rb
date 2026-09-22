require "rails_helper"

RSpec.describe "Articles", type: :request do
  include GoogleSignIn

  # sign_in_with_google signs in as the user behind google_auth_hash.
  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }

  describe "when signed out" do
    it "turns the list away to the landing page" do
      get articles_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "when signed in" do
    before { sign_in_with_google }

    it "is where the root page sends a signed-in user" do
      get root_path

      expect(response).to redirect_to(articles_path)
    end

    it "lists articles from all of the current user's feeds, newest first" do
      blog = create(:feed, user:, title: "My Blog")
      news = create(:feed, user:, title: "My News")
      create(:article, feed: blog, title: "Older Post", published_at: 2.days.ago)
      create(:article, feed: news, title: "Newer Post", published_at: 1.day.ago)

      get articles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Blog", "My News")
      expect(response.body.index("Newer Post")).to be < response.body.index("Older Post")
    end

    it "links each article to its original page" do
      create(:article, feed: create(:feed, user:), url: "https://example.com/posts/original")

      get articles_path

      expect(response.body).to include('href="https://example.com/posts/original"')
    end

    it "does not show another user's articles" do
      create(:article, title: "Someone Else's Post")

      get articles_path

      expect(response.body).not_to include("Someone Else&#39;s Post")
      expect(response.body).to include("まだ記事がありません。")
    end
  end
end
