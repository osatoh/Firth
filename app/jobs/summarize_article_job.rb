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
    return summary.update!(state: :failed, failure_reason: "missing_api_key") unless api_key

    extracted = ArticleExtractor.extract(summary.article.url)
    return summary.update!(state: :failed, failure_reason: extracted.reason.to_s) unless extracted.success?

    result = ArticleSummarizer.summarize(api_key:, text: extracted.text, language: summary.language)
    if result.success?
      summary.update!(state: :done, body: result.body)
    else
      summary.update!(state: :failed, failure_reason: result.reason)
    end
  rescue StandardError
    # Unexpected: still never leave the summary pending, but surface the bug.
    summary.update!(state: :failed, failure_reason: "api_error")
    raise
  end
end
