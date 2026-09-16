class Feed < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :url, presence: true, uniqueness: { scope: :user_id }
  validate :url_must_be_http

  private
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
