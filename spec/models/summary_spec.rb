require "rails_helper"

RSpec.describe Summary, type: :model do
  it "starts out pending" do
    expect(create(:summary)).to be_pending
  end

  describe "validations" do
    it "is invalid with a language users cannot choose" do
      summary = build(:summary, language: "fr")

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:language, :inclusion)
    end

    it "is invalid with an unknown state" do
      summary = build(:summary, state: "unknown")

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:state, :inclusion)
    end

    it "is invalid when the article already has a summary in the language" do
      existing = create(:summary)

      summary = build(:summary, article: existing.article, language: existing.language)

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:language, :taken)
    end

    it "allows another language for the same article" do
      existing = create(:summary, language: "ja")

      expect(build(:summary, article: existing.article, language: "en")).to be_valid
    end

    it "requires a body once done" do
      summary = build(:summary, :done, body: "")

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:body, :blank)
    end

    it "accepts extraction and API failure reasons when failed" do
      %w[blocked_address fetch_failed not_html no_content invalid_api_key rate_limited api_error].each do |failure_reason|
        expect(build(:summary, :failed, failure_reason:)).to be_valid
      end
    end

    it "requires a known failure reason when failed" do
      summary = build(:summary, :failed, failure_reason: "oops")

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:failure_reason, :inclusion)
    end

    it "has no failure reason unless failed" do
      summary = build(:summary, :done, failure_reason: "api_error")

      expect(summary).to be_invalid
      expect(summary.errors).to be_of_kind(:failure_reason, :present)
    end
  end

  it "is deleted with its article" do
    summary = create(:summary)

    expect { summary.article.destroy }.to change(Summary, :count).by(-1)
  end

  it "has a Japanese message for every failure reason" do
    Summary::FAILURE_REASONS.each do |reason|
      expect(I18n.exists?("summaries.failure_reasons.#{reason}", :ja)).to be(true), reason
    end
  end

  describe "live update of the article page" do
    let(:article) { create(:article) }
    let(:stream) { "#{article.to_gid_param}:summary:en" }

    it "replaces the summary with the pending one when a summary is requested" do
      expect { article.request_summary("en") }.to have_broadcasted_to(stream).exactly(:once)
        .with(a_string_including('action="replace"', 'target="summary"', I18n.t("articles.summary.pending")))
    end

    it "replaces the summary with the pending one when a failed summary is retried" do
      create(:summary, :failed, article:, language: "en", failure_reason: "api_error")

      expect { article.request_summary("en") }.to have_broadcasted_to(stream).exactly(:once)
        .with(a_string_including('action="replace"', I18n.t("articles.summary.pending")))
    end

    it "does not broadcast when a summary is requested again while in progress" do
      create(:summary, article:, language: "en")

      expect { article.request_summary("en") }.not_to have_broadcasted_to(stream)
    end

    it "does not broadcast a change that leaves the state alone" do
      summary = create(:summary, :done, article:, language: "en", body: "Old")

      expect { summary.update!(body: "New") }.not_to have_broadcasted_to(stream)
    end
  end
end
