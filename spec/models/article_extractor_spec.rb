require "rails_helper"

RSpec.describe ArticleExtractor do
  describe ".extract" do
    subject(:result) { described_class.extract(url) }

    let(:url) { "https://example.com/post" }
    let(:html) { file_fixture("article.html").read }

    def stub_page(body, content_type: "text/html; charset=utf-8", status: 200)
      stub_request(:get, url).to_return(status:, body:, headers: { "Content-Type" => content_type })
    end

    it "returns the main text of the article, without page chrome" do
      stub_page(html)

      expect(result).to be_success
      expect(result.text).to start_with("Why rivers meander\nRivers rarely run straight.")
      expect(result.text).to include("leaving an oxbow lake behind.")
      expect(result.text).not_to include("Home", "Related", "Copyright", "tracking", "color: red")
    end

    it "falls back to <main> and then <body> when there is no <article>" do
      stub_page(html.gsub("article>", "main>"))
      expect(result.text).to start_with("Why rivers meander")

      stub_page(html.gsub("article>", "div>"))
      expect(described_class.extract(url).text).to start_with("Why rivers meander")
    end

    it "decodes the page using the charset from the Content-Type header" do
      stub_page(html.sub("Rivers rarely", "Les rivières rarement").encode("ISO-8859-1"),
                content_type: "text/html; charset=ISO-8859-1")

      expect(result.text).to include("Les rivières rarement")
    end

    it "decodes the page using <meta charset> when the header has none" do
      body = html.sub("<head>", '<head><meta charset="Shift_JIS">').sub("Rivers rarely", "川は曲がる。Rivers rarely")
      stub_page(body.encode("Shift_JIS"), content_type: "text/html")

      expect(result.text).to include("川は曲がる。")
    end

    it "truncates long articles" do
      stub_const("ArticleExtractor::MAX_LENGTH", 50)
      stub_page(html)

      expect(result.text.length).to eq 50
    end

    it "fails with :not_html for other content types" do
      stub_page("%PDF-1.7", content_type: "application/pdf")

      expect(result).to eq ArticleExtractor::Failure.new(:not_html)
    end

    it "fails with :no_content when too little text is found" do
      stub_page("<html><body><article><p>Please enable JavaScript.</p></article></body></html>")

      expect(result).to eq ArticleExtractor::Failure.new(:no_content)
    end

    it "fails with :fetch_failed on an HTTP error" do
      stub_page("Not Found", status: 404)

      expect(result).to eq ArticleExtractor::Failure.new(:fetch_failed)
    end

    it "fails with :fetch_failed on a network error" do
      stub_request(:get, url).to_timeout

      expect(result).to eq ArticleExtractor::Failure.new(:fetch_failed)
    end

    context "when the URL points at a private address" do
      let(:url) { "http://127.0.0.1/admin" }

      it "fails with :blocked_address without making a request" do
        allow(Resolv).to receive(:getaddresses).and_call_original

        expect(result).to eq ArticleExtractor::Failure.new(:blocked_address)
        expect(a_request(:any, //)).not_to have_been_made
      end
    end

    it "fails with :fetch_failed for a non-http(s) URL" do
      expect(described_class.extract("javascript:alert(1)")).to eq ArticleExtractor::Failure.new(:fetch_failed)
    end
  end
end
