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
end
