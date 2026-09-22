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

    it "links each article to its own page" do
      article = create(:article, feed: create(:feed, user:))

      get articles_path

      expect(response.body).to include(%(href="#{article_path(article)}"))
    end
  end

  describe "GET /articles/:id" do
    it "turns a signed-out visitor away to the landing page" do
      get article_path(create(:article))

      expect(response).to redirect_to(root_path)
    end

    context "when signed in" do
      before { sign_in_with_google }

      it "shows the title, feed, published date, and original link" do
        article = create(:article, feed: create(:feed, user:, title: "My Blog"), title: "Hello World",
                                   url: "https://example.com/posts/hello", published_at: Time.zone.local(2026, 9, 1, 12, 34))

        get article_path(article)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Hello World", "My Blog", "2026-09-01 12:34",
                                         'href="https://example.com/posts/hello"')
      end

      it "returns 404 for another user's article" do
        get article_path(create(:article))

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
