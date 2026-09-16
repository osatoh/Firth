require "rails_helper"

RSpec.describe "Feeds", type: :request do
  include GoogleSignIn

  # sign_in_with_google signs in as the user behind google_auth_hash.
  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }

  describe "when signed out" do
    it "turns every action away to the landing page" do
      feed = create(:feed)

      get feeds_path
      expect(response).to redirect_to(root_path)

      # The landing page tells them why they were turned away.
      follow_redirect!
      expect(response.body).to include("サインインしてください。")

      get new_feed_path
      expect(response).to redirect_to(root_path)

      expect { post feeds_path, params: { feed: { title: "Example Blog", url: "https://example.com/feed.xml" } } }
        .not_to change(Feed, :count)
      expect(response).to redirect_to(root_path)

      get edit_feed_path(feed)
      expect(response).to redirect_to(root_path)

      patch feed_path(feed), params: { feed: { title: "Renamed" } }
      expect(response).to redirect_to(root_path)
      expect(feed.reload.title).to eq("Example Blog")

      expect { delete feed_path(feed) }.not_to change(Feed, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "when signed in" do
    before { sign_in_with_google }

    describe "index" do
      it "lists only the current user's feeds" do
        mine = create(:feed, user:, title: "My Blog")
        others = create(:feed, title: "Someone Else's Blog")

        get feeds_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(mine.title)
        expect(response.body).not_to include(others.title)
      end
    end

    describe "create" do
      it "adds a feed" do
        expect {
          post feeds_path, params: { feed: { title: "Example Blog", url: "https://example.com/feed.xml" } }
        }.to change(user.feeds, :count).by(1)

        expect(response).to redirect_to(feeds_path)
        expect(user.feeds.last).to have_attributes(title: "Example Blog", url: "https://example.com/feed.xml")

        follow_redirect!
        expect(response.body).to include("フィードを追加しました。")
      end

      it "rejects an invalid URL and re-renders the form" do
        expect {
          post feeds_path, params: { feed: { title: "Example Blog", url: "not a url" } }
        }.not_to change(Feed, :count)

        expect(response).to have_http_status(422)
      end
    end

    describe "update" do
      it "updates the current user's feed" do
        feed = create(:feed, user:, title: "Old Name")

        patch feed_path(feed), params: { feed: { title: "New Name" } }

        expect(response).to redirect_to(feeds_path)
        expect(feed.reload.title).to eq("New Name")
      end

      it "does not update when the URL is invalid" do
        feed = create(:feed, user:, url: "https://example.com/feed.xml")

        patch feed_path(feed), params: { feed: { url: "ftp://example.com/feed.xml" } }

        expect(response).to have_http_status(422)
        expect(feed.reload.url).to eq("https://example.com/feed.xml")
      end

      it "cannot touch another user's feed" do
        feed = create(:feed, title: "Someone Else's Blog")

        get edit_feed_path(feed)
        expect(response).to have_http_status(:not_found)

        patch feed_path(feed), params: { feed: { title: "Hijacked" } }
        expect(response).to have_http_status(:not_found)
        expect(feed.reload.title).to eq("Someone Else's Blog")
      end
    end

    describe "destroy" do
      it "deletes the current user's feed" do
        feed = create(:feed, user:)

        expect { delete feed_path(feed) }.to change(user.feeds, :count).by(-1)

        expect(response).to redirect_to(feeds_path)
      end

      it "cannot delete another user's feed" do
        feed = create(:feed)

        expect { delete feed_path(feed) }.not_to change(Feed, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
