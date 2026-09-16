# request spec から Google サインインを踏むための共有ヘルパー。
module GoogleSignIn
  extend ActiveSupport::Concern

  included do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google_oauth2] = google_auth_hash
    end

    after do
      OmniAuth.config.mock_auth[:google_oauth2] = nil
      OmniAuth.config.test_mode = false
    end
  end

  def google_auth_hash
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-1",
      info: { email: "user@example.com", name: "Test User" }
    )
  end

  def sign_in_with_google
    post "/auth/google_oauth2"
    follow_redirect!
  end
end
