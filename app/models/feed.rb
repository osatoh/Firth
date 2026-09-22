class Feed < ApplicationRecord
  belongs_to :user
  has_many :articles, dependent: :delete_all

  validates :title, presence: true
  validates :url, presence: true, uniqueness: { scope: :user_id }
  validate :url_must_be_http

  before_validation :normalize_url
  # Fetch right away instead of waiting for the next scheduled run (spec 2.3.5).
  # A new record's URL counts as changed, so this also covers creation.
  after_commit :enqueue_fetch, if: :saved_change_to_url?

  private
    def enqueue_fetch
      FetchFeedJob.perform_later(self)
    end

    # Fold away the differences RFC 3986 calls equivalent, so that the same
    # feed cannot be registered twice under two spellings of one URL.
    # The path is left alone: unlike the scheme and host, it is case-sensitive,
    # and a trailing slash makes it a different path.
    def normalize_url
      return if url.blank?

      uri = URI.parse(url)
      return unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.empty?
      self.url = uri.to_s
    rescue URI::InvalidURIError
      # Leave it as typed; url_must_be_http reports the problem.
    end

    # Only checks that the URL is shaped like something we can fetch.
    # Whether it actually resolves is the fetch job's concern (task 2.2).
    def url_must_be_http
      return if url.blank?

      uri = URI.parse(url)
      errors.add(:url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:url, :invalid)
    end
end
