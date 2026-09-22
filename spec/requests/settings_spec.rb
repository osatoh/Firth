require "rails_helper"

RSpec.describe "Settings", type: :request do
  include GoogleSignIn

  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }

  describe "when signed out" do
    it "turns every action away to the landing page" do
      get edit_settings_path
      expect(response).to redirect_to(root_path)

      patch settings_path, params: { user: { summary_language: "en" } }
      expect(response).to redirect_to(root_path)

      delete settings_api_key_path
      expect(response).to redirect_to(root_path)

      expect { delete settings_account_path }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "when signed in" do
    before { sign_in_with_google }

    describe "edit" do
      it "shows the key masked, never in full" do
        user.update!(anthropic_api_key: "sk-ant-api03-secret1234")

        get edit_settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("sk-ant-…1234")
        expect(response.body).not_to include("secret1234")
      end

      it "says when no key is set" do
        get edit_settings_path

        expect(response.body).to include("API キーは未設定です。")
      end
    end

    describe "update" do
      it "saves the key and the summary language" do
        patch settings_path, params: { user: { anthropic_api_key: "sk-ant-api03-new5678", summary_language: "en" } }

        expect(response).to redirect_to(edit_settings_path)
        expect(user.reload).to have_attributes(anthropic_api_key: "sk-ant-api03-new5678", summary_language: "en")

        follow_redirect!
        expect(response.body).to include("設定を保存しました。")
      end

      it "keeps the existing key when the key field is left blank" do
        user.update!(anthropic_api_key: "sk-ant-api03-secret1234")

        patch settings_path, params: { user: { anthropic_api_key: "", summary_language: "en" } }

        expect(user.reload).to have_attributes(anthropic_api_key: "sk-ant-api03-secret1234", summary_language: "en")
      end

      it "rejects a malformed key without echoing it back" do
        patch settings_path, params: { user: { anthropic_api_key: "wrong-secret9999" } }

        expect(response).to have_http_status(422)
        expect(response.body).to include("Claude API キーは sk-ant- で始まる必要があります")
        expect(response.body).not_to include("wrong-secret9999")
        expect(user.reload.anthropic_api_key).to be_nil
      end

      it "rejects an unsupported language" do
        patch settings_path, params: { user: { summary_language: "xx" } }

        expect(response).to have_http_status(422)
        expect(user.reload.summary_language).to eq("ja")
      end
    end

    describe "destroy api key" do
      it "deletes the key" do
        user.update!(anthropic_api_key: "sk-ant-api03-secret1234")

        delete settings_api_key_path

        expect(response).to redirect_to(edit_settings_path)
        expect(user.reload.anthropic_api_key).to be_nil
      end
    end

    describe "destroy account" do
      it "deletes the user, signs out and says so" do
        expect { delete settings_account_path }.to change(User, :count).by(-1)
        expect(response).to redirect_to(root_path)

        follow_redirect!
        expect(response.body).to include("アカウントを削除しました。")

        get edit_settings_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
