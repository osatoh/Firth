# An AI summary of an article in one language (ADR 0004). Created as pending
# when the user asks for it, then marked done or failed by the summary job.
class Summary < ApplicationRecord
  # Codes, not messages, so the UI can translate them via ja.yml.
  API_FAILURE_REASONS = %w[missing_api_key invalid_api_key rate_limited api_error].freeze
  # Failures the user fixes on the settings page rather than by retrying later.
  KEY_FAILURE_REASONS = %w[missing_api_key invalid_api_key].freeze
  FAILURE_REASONS = (ArticleExtractor::FAILURE_REASONS.map(&:to_s) + API_FAILURE_REASONS).freeze

  belongs_to :article

  enum :state, { pending: "pending", done: "done", failed: "failed" }, default: :pending, validate: true

  validates :language, inclusion: { in: User::SUMMARY_LANGUAGES }, uniqueness: { scope: :article_id }
  validates :body, presence: true, if: :done?
  validates :failure_reason, inclusion: { in: FAILURE_REASONS }, if: :failed?
  validates :failure_reason, absence: true, unless: :failed?

  def fixable_in_settings? = failure_reason.in?(KEY_FAILURE_REASONS)

  # Puts a failed summary back to pending. Only one of several concurrent
  # callers wins, so the caller that gets true is the one to enqueue the job.
  def retry_if_failed
    return false unless failed?

    reset = self.class.where(id:, state: :failed).update_all(state: :pending, failure_reason: nil, updated_at: Time.current) == 1
    reload
    reset
  end

  # Replaces the summary on the article pages that are showing it.
  def broadcast_update
    broadcast_replace_to article, :summary, language, target: "summary", partial: "articles/summary", locals: { article:, summary: self }
  end
end
