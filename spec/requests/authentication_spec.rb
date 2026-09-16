require "rails_helper"

RSpec.describe "Requiring a sign-in", type: :request do
  # Stand in for an ordinary page (one that is neither the landing page nor an auth endpoint)
  # with a controller inheriting from ApplicationController, and a route, local to this spec.
  around do |example|
    # Load the real routes first: left lazy, the draw below would wipe them out.
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

  context "when signed out" do
    it "redirects to the landing page" do
      get "/spec/protected"

      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in" do
    include GoogleSignIn

    it "renders the page" do
      sign_in_with_google

      get "/spec/protected"

      expect(response).to have_http_status(:ok)
    end
  end
end
