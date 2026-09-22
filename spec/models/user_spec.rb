require "rails_helper"

RSpec.describe User do
  describe "validations" do
    it "is valid with a Google uid, an email and a name" do
      expect(build(:user)).to be_valid
    end

    %i[google_uid email name].each do |attribute|
      it "is invalid without #{attribute}" do
        expect(build(:user, attribute => nil)).not_to be_valid
      end
    end

    it "is invalid when the Google uid is already taken" do
      google_uid = create(:user).google_uid

      expect(build(:user, google_uid:)).not_to be_valid
    end
  end

  describe "summary_language" do
    it "defaults to Japanese" do
      expect(User.new.summary_language).to eq("ja")
    end

    it "is invalid with an unsupported language" do
      expect(build(:user, summary_language: "xx")).not_to be_valid
    end
  end

  describe "anthropic_api_key" do
    it "is stored encrypted" do
      user = create(:user, anthropic_api_key: "sk-ant-api03-secret1234")

      raw = User.connection.select_value("SELECT anthropic_api_key FROM users WHERE id = #{user.id}")
      expect(raw).not_to include("secret1234")
      expect(user.reload.anthropic_api_key).to eq("sk-ant-api03-secret1234")
    end

    it "is optional" do
      expect(build(:user, anthropic_api_key: nil)).to be_valid
    end

    it "must look like an Anthropic key" do
      expect(build(:user, anthropic_api_key: "not-a-key")).not_to be_valid
    end

    it "strips surrounding whitespace" do
      expect(build(:user, anthropic_api_key: " sk-ant-abc \n").anthropic_api_key).to eq("sk-ant-abc")
    end
  end

  describe "#masked_anthropic_api_key" do
    it "shows only the last four characters" do
      user = build(:user, anthropic_api_key: "sk-ant-api03-secret1234")

      expect(user.masked_anthropic_api_key).to eq("sk-ant-…1234")
    end

    it "is nil without a key" do
      expect(build(:user).masked_anthropic_api_key).to be_nil
    end
  end
end
