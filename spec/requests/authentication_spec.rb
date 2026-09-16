require "rails_helper"

RSpec.describe "サインインの要求", type: :request do
  # ランディングと認証まわり以外の「普通のページ」の代わりとして、
  # ApplicationController を継承したコントローラとルートをこの spec の中だけで用意する。
  around do |example|
    # 遅延ロードのままだと下の draw でアプリ本来のルートが失われるので、先に読み込ませる。
    Rails.application.reload_routes_unless_loaded

    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "spec/protected", to: "spec_protected#show"
    end

    example.run
  ensure
    Rails.application.routes.disable_clear_and_finalize = false
    Rails.application.reload_routes!
  end

  before do
    stub_const("SpecProtectedController", Class.new(ApplicationController) do
      def show
        render plain: "protected"
      end
    end)
  end

  context "サインインしていないとき" do
    it "ランディングへリダイレクトする" do
      get "/spec/protected"

      expect(response).to redirect_to(root_path)
    end
  end

  context "サインインしているとき" do
    include GoogleSignIn

    it "そのページを表示する" do
      sign_in_with_google

      get "/spec/protected"

      expect(response).to have_http_status(:ok)
    end
  end
end
