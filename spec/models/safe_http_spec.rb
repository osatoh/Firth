require "rails_helper"

RSpec.describe SafeHttp do
  describe ".get" do
    it "returns the body of a successful response" do
      stub_request(:get, "https://example.com/feed.xml").to_return(status: 200, body: "ok")

      expect(described_class.get("https://example.com/feed.xml")).to eq "ok"
    end

    it "connects to the checked address while keeping the hostname for Host and TLS" do
      stub_request(:get, "https://example.com/feed.xml").to_return(status: 200, body: "ok")
      http = nil
      allow(Net::HTTP).to receive(:new).and_wrap_original { |original, *args| http = original.call(*args) }

      described_class.get("https://example.com/feed.xml")

      expect(http).to have_attributes(address: "example.com", ipaddr: "93.184.215.14", use_ssl?: true)
    end

    it "rejects non-http(s) URLs" do
      expect { described_class.get("file:///etc/passwd") }.to raise_error(SafeHttp::Error, /not an http/)
    end

    [
      "http://127.0.0.1/", "http://10.0.0.1/", "http://169.254.169.254/latest/meta-data/",
      "http://192.168.1.1/", "http://0.0.0.0/", "http://[::1]/", "http://[::ffff:127.0.0.1]/",
      "http://[fd00::1]/", "http://[fe80::1]/"
    ].each do |url|
      it "refuses #{url}" do
        allow(Resolv).to receive(:getaddresses).and_call_original

        expect { described_class.get(url) }.to raise_error(SafeHttp::BlockedAddressError)
        expect(a_request(:any, //)).not_to have_been_made
      end
    end

    it "refuses a hostname that resolves to a private address" do
      allow(Resolv).to receive(:getaddresses).with("internal.example").and_return([ "93.184.215.14", "10.1.2.3" ])

      expect { described_class.get("http://internal.example/") }.to raise_error(SafeHttp::BlockedAddressError)
    end

    it "refuses a redirect to a private address" do
      stub_request(:get, "https://example.com/feed.xml")
        .to_return(status: 302, headers: { "Location" => "http://metadata.internal/latest" })
      allow(Resolv).to receive(:getaddresses).with("metadata.internal").and_return([ "169.254.169.254" ])

      expect { described_class.get("https://example.com/feed.xml") }.to raise_error(SafeHttp::BlockedAddressError)
      expect(a_request(:get, "http://metadata.internal/latest")).not_to have_been_made
    end

    it "gives up after too many redirects" do
      stub_request(:get, "https://example.com/loop").to_return(status: 302, headers: { "Location" => "/loop" })

      expect { described_class.get("https://example.com/loop") }.to raise_error(SafeHttp::Error, /too many redirects/)
    end

    it "refuses a body larger than the cap" do
      stub_const("SafeHttp::MAX_BODY_SIZE", 10)
      stub_request(:get, "https://example.com/big").to_return(status: 200, body: "x" * 11)

      expect { described_class.get("https://example.com/big") }.to raise_error(SafeHttp::Error, /exceeds/)
    end
  end
end
