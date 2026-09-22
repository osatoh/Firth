require "rails_helper"

RSpec.describe WebUrl do
  describe ".valid?" do
    it { expect(described_class.valid?("https://example.com/a")).to be true }
    it { expect(described_class.valid?("http://example.com")).to be true }
    it { expect(described_class.valid?("javascript:alert(1)")).to be false }
    it { expect(described_class.valid?("ftp://example.com/")).to be false }
    it { expect(described_class.valid?("http:///path")).to be false }
    it { expect(described_class.valid?("not a url")).to be false }
    it { expect(described_class.valid?(nil)).to be false }
  end
end
