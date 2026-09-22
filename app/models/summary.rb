# An AI summary of an article in one language (ADR 0004). Created as pending
# when the user asks for it, then marked done or failed by the summary job.
class Summary < ApplicationRecord
  # Codes, not messages, so the UI can translate them via ja.yml.
  API_FAILURE_REASONS = %w[missing_api_key invalid_api_key rate_limited api_error].freeze
  FAILURE_REASONS = (ArticleExtractor::FAILURE_REASONS.map(&:to_s) + API_FAILURE_REASONS).freeze

  belongs_to :article

  enum :state, { pending: "pending", done: "done", failed: "failed" }, default: :pending, validate: true

  validates :language, inclusion: { in: User::SUMMARY_LANGUAGES }, uniqueness: { scope: :article_id }
  validates :body, presence: true, if: :done?
  validates :failure_reason, inclusion: { in: FAILURE_REASONS }, if: :failed?
  validates :failure_reason, absence: true, unless: :failed?
end
