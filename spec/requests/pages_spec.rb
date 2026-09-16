require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "ランディング" do
    it "サインインしていなくても表示できる" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end
