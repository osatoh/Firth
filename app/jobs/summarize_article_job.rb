# Summarises an article for the summary's language (spec 4.2): extracts the
# content (ADR 0005), then asks Claude with the requesting user's own key.
#
# Every outcome ends in done or failed with a reason code, so a summary never
# stays pending.
class SummarizeArticleJob < ApplicationJob
  queue_as :default

  # The summary was deleted after the job was enqueued.
  discard_on ActiveJob::DeserializationError

  def perform(summary)
    return unless summary.pending?

    api_key = summary.article.feed.user.anthropic_api_key
    return finish(summary, state: :failed, failure_reason: "missing_api_key") unless api_key

    extracted = ArticleExtractor.extract(summary.article.url)
    return finish(summary, state: :failed, failure_reason: extracted.reason.to_s) unless extracted.success?

    result = ArticleSummarizer.summarize(api_key:, text: extracted.text, language: summary.language)
    if result.success?
      finish(summary, state: :done, body: result.body)
    else
      finish(summary, state: :failed, failure_reason: result.reason)
    end
  rescue StandardError
    # Unexpected: still never leave the summary pending, but surface the bug.
    finish(summary, state: :failed, failure_reason: "api_error")
    raise
  end

  private
    # The single place a summary leaves pending, so the page updates live from here.
    def finish(summary, **attributes)
      summary.update!(**attributes)
      summary.broadcast_update
    end
end
