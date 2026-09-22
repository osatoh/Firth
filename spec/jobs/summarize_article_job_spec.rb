require "rails_helper"

RSpec.describe SummarizeArticleJob, type: :job do
  let(:user) { create(:user, anthropic_api_key: "sk-ant-user-key") }
  let(:article) { create(:article, feed: create(:feed, user:), url: "https://example.com/post") }
  let(:summary) { create(:summary, article:, language: "en") }
  let(:messages_url) { "https://api.anthropic.com/v1/messages" }

  before do
    stub_request(:get, article.url).to_return(
      body: file_fixture("article.html").read, headers: { "Content-Type" => "text/html; charset=utf-8" }
    )
  end

  def stub_claude(status: 200, body: nil, error_type: nil)
    body ||= if error_type
      { type: "error", error: { type: error_type, message: "Something went wrong" } }
    else
      {
        id: "msg_1", type: "message", role: "assistant", model: ArticleSummarizer::MODEL,
        content: [ { type: "text", text: "Rivers bend over time." } ],
        stop_reason: "end_turn", usage: { input_tokens: 10, output_tokens: 5 }
      }
    end
    stub_request(:post, messages_url).to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "knows the name of every summary language" do
    expect(ArticleSummarizer::LANGUAGE_NAMES.keys).to match_array User::SUMMARY_LANGUAGES
  end

  it "stores the summary returned by Claude" do
    stub_claude

    described_class.perform_now(summary)

    expect(summary.reload).to be_done
    expect(summary.body).to eq "Rivers bend over time."
  end

  it "calls Claude with the user's own key, the article text and the summary language" do
    stub_claude

    described_class.perform_now(summary)

    expect(a_request(:post, messages_url).with(headers: { "X-Api-Key" => "sk-ant-user-key" }) { |request|
      params = JSON.parse(request.body)
      params["model"] == ArticleSummarizer::MODEL &&
        params["system"].include?("English") &&
        params["messages"].sole["content"].include?("Rivers rarely run straight.")
    }).to have_been_made.once
  end

  it "fails with the extractor's reason when the article cannot be extracted" do
    stub_request(:get, article.url).to_return(status: 404)

    described_class.perform_now(summary)

    expect(summary.reload).to be_failed
    expect(summary.failure_reason).to eq "fetch_failed"
    expect(a_request(:post, messages_url)).not_to have_been_made
  end

  it "fails with missing_api_key without calling Claude when the user has no key" do
    user.update!(anthropic_api_key: nil)

    described_class.perform_now(summary)

    expect(summary.reload.failure_reason).to eq "missing_api_key"
    expect(a_request(:any, //)).not_to have_been_made
  end

  {
    [ 401, "authentication_error" ] => "invalid_api_key",
    [ 403, "permission_error" ] => "invalid_api_key",
    [ 429, "rate_limit_error" ] => "rate_limited",
    [ 529, "overloaded_error" ] => "rate_limited",
    [ 400, "invalid_request_error" ] => "api_error",
    [ 500, "api_error" ] => "api_error"
  }.each do |(status, error_type), reason|
    it "fails with #{reason} when Claude responds #{status} #{error_type}" do
      stub_claude(status:, error_type:)

      expect { described_class.perform_now(summary) }.not_to raise_error
      expect(summary.reload).to be_failed
      expect(summary.failure_reason).to eq reason
    end
  end

  it "does not retry an invalid key" do
    stub_claude(status: 401, error_type: "authentication_error")

    described_class.perform_now(summary)

    expect(a_request(:post, messages_url)).to have_been_made.once
  end

  it "fails with api_error when the connection to Claude fails" do
    stub_request(:post, messages_url).to_timeout

    described_class.perform_now(summary)

    expect(summary.reload.failure_reason).to eq "api_error"
  end

  it "fails with api_error when Claude returns no text" do
    stub_claude(body: {
      id: "msg_1", type: "message", role: "assistant", model: ArticleSummarizer::MODEL,
      content: [], stop_reason: "refusal", usage: { input_tokens: 10, output_tokens: 0 }
    })

    described_class.perform_now(summary)

    expect(summary.reload.failure_reason).to eq "api_error"
  end

  it "marks the summary failed and re-raises on an unexpected error" do
    allow(ArticleExtractor).to receive(:extract).and_raise(ArgumentError, "boom")

    expect { described_class.perform_now(summary) }.to raise_error(ArgumentError)
    expect(summary.reload.failure_reason).to eq "api_error"
  end

  it "leaves a summary that is no longer pending alone" do
    summary.update!(state: :done, body: "Earlier summary")

    described_class.perform_now(summary)

    expect(summary.reload.body).to eq "Earlier summary"
    expect(a_request(:any, //)).not_to have_been_made
  end

  describe "live update of the article page" do
    let(:stream) { "#{article.to_gid_param}:summary:en" }

    it "replaces the summary with the finished one" do
      stub_claude

      expect { described_class.perform_now(summary) }.to have_broadcasted_to(stream)
        .with(a_string_including('action="replace"', 'target="summary"', "Rivers bend over time."))
    end

    it "replaces the summary with a failure too" do
      user.update!(anthropic_api_key: nil)

      expect { described_class.perform_now(summary) }.to have_broadcasted_to(stream)
        .with(a_string_including(I18n.t("summaries.failure_reasons.missing_api_key")))
    end
  end
end
