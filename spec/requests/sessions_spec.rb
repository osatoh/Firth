require "rails_helper"

RSpec.describe "Sessions", type: :request do
  include GoogleSignIn

  describe "sign-in" do
    it "creates a user on the first sign-in and stores them in the session" do
      expect { sign_in_with_google }.to change(User, :count).by(1)

      user = User.last
      expect(user).to have_attributes(google_uid: "google-uid-1", email: "user@example.com", name: "Test User")
      expect(session[:user_id]).to eq(user.id)
    end

    it "reuses the existing user on a later sign-in and refreshes the email and name" do
      user = create(:user, google_uid: "google-uid-1", email: "old@example.com", name: "Old Name")

      expect { sign_in_with_google }.not_to change(User, :count)

      expect(user.reload).to have_attributes(email: "user@example.com", name: "Test User")
      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe "sign-out" do
    it "empties the session" do
      sign_in_with_google

      delete sign_out_path

      expect(session[:user_id]).to be_nil
    end
  end

  describe "an authentication failure" do
    it "redirects instead of erroring out" do
      OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

      post "/auth/google_oauth2"
      follow_redirect! # the callback -> /auth/failure
      follow_redirect! # /auth/failure -> the root path

      expect(response).to redirect_to("/")
      expect(User.count).to eq(0)
    end
  end
end
