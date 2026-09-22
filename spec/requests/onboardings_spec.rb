require "rails_helper"

RSpec.describe "Onboardings", type: :request do
  include GoogleSignIn

  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }

  describe "when signed out" do
    it "turns every action away to the landing page" do
      get onboarding_path
      expect(response).to redirect_to(root_path)

      patch onboarding_path, params: { user: { summary_language: "en" } }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "when signed in" do
    before { sign_in_with_google }

    describe "show" do
      it "asks for the key and the language, with a way to skip" do
        get onboarding_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Claude API キー", "要約の言語", "スキップ")
        expect(response.body).to include(%(href="#{articles_path}"))
      end
    end

    describe "update" do
      it "saves the key and the language, then goes to the article list" do
        patch onboarding_path, params: { user: { anthropic_api_key: "sk-ant-api03-new5678", summary_language: "en" } }

        expect(response).to redirect_to(articles_path)
        expect(user.reload).to have_attributes(anthropic_api_key: "sk-ant-api03-new5678", summary_language: "en")
      end

      it "treats a blank key as no key" do
        patch onboarding_path, params: { user: { anthropic_api_key: "", summary_language: "ko" } }

        expect(response).to redirect_to(articles_path)
        expect(user.reload).to have_attributes(anthropic_api_key: nil, summary_language: "ko")
      end

      it "shows the form again with the error when the key is malformed" do
        patch onboarding_path, params: { user: { anthropic_api_key: "not-a-key", summary_language: "en" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload.anthropic_api_key).to be_nil
      end
    end
  end
end
