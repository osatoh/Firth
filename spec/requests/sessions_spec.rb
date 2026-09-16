require "rails_helper"

RSpec.describe "Sessions", type: :request do
  include GoogleSignIn

  describe "サインイン" do
    it "初回サインインでユーザーを作成し、セッションに保存する" do
      expect { sign_in_with_google }.to change(User, :count).by(1)

      user = User.last
      expect(user).to have_attributes(google_uid: "google-uid-1", email: "user@example.com", name: "Test User")
      expect(session[:user_id]).to eq(user.id)
    end

    it "2 回目以降は既存のユーザーを使い回し、メールアドレスと名前を更新する" do
      user = create(:user, google_uid: "google-uid-1", email: "old@example.com", name: "Old Name")

      expect { sign_in_with_google }.not_to change(User, :count)

      expect(user.reload).to have_attributes(email: "user@example.com", name: "Test User")
      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe "サインアウト" do
    it "セッションを空にする" do
      sign_in_with_google

      delete sign_out_path

      expect(session[:user_id]).to be_nil
    end
  end

  describe "認証失敗" do
    it "エラーにならずリダイレクトする" do
      OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

      post "/auth/google_oauth2"
      follow_redirect! # コールバック -> /auth/failure
      follow_redirect! # /auth/failure -> トップ

      expect(response).to redirect_to("/")
      expect(User.count).to eq(0)
    end
  end
end
