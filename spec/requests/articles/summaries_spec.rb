require "rails_helper"

RSpec.describe "Article summaries", type: :request do
  include GoogleSignIn
  include ActiveJob::TestHelper

  let(:user) { User.find_by!(google_uid: google_auth_hash[:uid]) }
  let(:article) { create(:article, feed: create(:feed, user:)) }

  describe "when signed out" do
    it "turns the request away to the landing page" do
      post article_summary_path(create(:article))

      expect(response).to redirect_to(root_path)
    end
  end

  describe "when signed in" do
    before { sign_in_with_google }

    context "with an API key" do
      before { user.update!(anthropic_api_key: "sk-ant-key", summary_language: "en") }

      it "creates a pending summary in the user's language and enqueues the job" do
        expect {
          post article_summary_path(article)
        }.to have_enqueued_job(SummarizeArticleJob)

        expect(article.summaries.sole).to have_attributes(language: "en", state: "pending")
        expect(response).to redirect_to(article_path(article))
      end

      it "reuses a done summary without enqueuing a job" do
        create(:summary, :done, article:, language: "en")

        expect { post article_summary_path(article) }.not_to have_enqueued_job(SummarizeArticleJob)

        expect(article.summaries.count).to eq 1
      end

      it "does not enqueue a second job while one is pending" do
        create(:summary, article:, language: "en")

        expect { post article_summary_path(article) }.not_to have_enqueued_job(SummarizeArticleJob)
      end

      it "retries a failed summary by resetting it to pending" do
        summary = create(:summary, :failed, article:, language: "en")

        expect { post article_summary_path(article) }.to have_enqueued_job(SummarizeArticleJob).with(summary)

        expect(summary.reload).to have_attributes(state: "pending", failure_reason: nil)
      end

      it "summarises afresh in a language that has no summary yet" do
        create(:summary, :done, article:, language: "ja")

        expect { post article_summary_path(article) }.to have_enqueued_job(SummarizeArticleJob)

        expect(article.summaries.pluck(:language)).to contain_exactly("ja", "en")
      end

      it "cannot summarise another user's article" do
        post article_summary_path(create(:article))

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without an API key" do
      it "guides the user to settings and enqueues nothing" do
        expect { post article_summary_path(article) }.not_to have_enqueued_job(SummarizeArticleJob)

        expect(article.summaries).to be_empty
        expect(response).to redirect_to(edit_settings_path)
        expect(flash[:alert]).to eq I18n.t("articles.summaries.create.missing_api_key")
      end
    end

    describe "the article page" do
      before { user.update!(summary_language: "en") }

      it "offers the summarise button and subscribes to the summary stream" do
        get article_path(article)

        expect(response.body).to include(%(action="#{article_summary_path(article)}"), "turbo-cable-stream-source")
      end

      it "shows a done summary in the current language as plain text" do
        create(:summary, :done, article:, language: "en", body: "First <b>line</b>")
        create(:summary, :done, article:, language: "ja", body: "日本語の要約")

        get article_path(article)

        expect(response.body).to include("First &lt;b&gt;line&lt;/b&gt;")
        expect(response.body).not_to include("日本語の要約")
      end

      it "shows a pending summary as in progress" do
        create(:summary, article:, language: "en")

        get article_path(article)

        expect(response.body).to include("要約中…")
      end

      it "shows why a summary failed, with a link to settings for key problems" do
        create(:summary, :failed, article:, language: "en", failure_reason: "invalid_api_key")

        get article_path(article)

        expect(response.body).to include(I18n.t("summaries.failure_reasons.invalid_api_key"), %(href="#{edit_settings_path}"))
      end
    end
  end
end
