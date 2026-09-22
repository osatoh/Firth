require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "landing" do
    it "explains what Firth is without a sign-in" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(*I18n.t("pages.landing.features"))
    end
  end
end
