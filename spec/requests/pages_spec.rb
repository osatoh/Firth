require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "landing" do
    it "renders without a sign-in" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end
