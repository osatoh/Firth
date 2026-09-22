require "rails_helper"

RSpec.describe "Feeds::Imports", type: :request do
  include GoogleSignIn

  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }

  def upload(name, type = "text/x-opml")
    { file: fixture_file_upload("opml/#{name}", type) }
  end

  it "turns signed-out visitors away" do
    get new_feeds_import_path
    expect(response).to redirect_to(root_path)

    expect { post feeds_import_path, params: upload("subscriptions.opml") }.not_to change(Feed, :count)
    expect(response).to redirect_to(root_path)
  end

  describe "when signed in" do
    before { sign_in_with_google }

    it "is linked from the feeds page" do
      get feeds_path
      expect(response.body).to include(new_feeds_import_path)

      get new_feeds_import_path
      expect(response).to have_http_status(:ok)
    end

    it "imports the feeds and summarises the result" do
      create(:feed, user:, url: "https://example.com/feed.xml")

      expect { post feeds_import_path, params: upload("subscriptions.opml") }
        .to change(user.feeds, :count).by(2)

      expect(response).to redirect_to(feeds_path)
      follow_redirect!
      expect(response.body).to include("2 件追加、1 件は登録済み、1 件は無効、0 件は上限のため追加できませんでした。")
    end

    it "rejects a file that is not OPML" do
      expect { post feeds_import_path, params: upload("not_xml.txt", "text/plain") }.not_to change(Feed, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("OPML ファイルとして読み込めませんでした。")
    end

    it "rejects a missing file" do
      post feeds_import_path

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("OPML ファイルを選択してください。")
    end

    it "rejects a file over the size cap" do
      stub_const("OpmlImport::MAX_BYTES", 10)

      expect { post feeds_import_path, params: upload("subscriptions.opml") }.not_to change(Feed, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("ファイルが大きすぎます")
    end
  end
end
