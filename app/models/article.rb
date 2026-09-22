class Article < ApplicationRecord
  belongs_to :feed
  has_many :summaries, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }
  validates :url, presence: true
  validates :title, presence: true

  # Some feeds omit publication dates; those articles fall back to when they were fetched.
  scope :newest_first, -> { order(Arel.sql("COALESCE(articles.published_at, articles.created_at) DESC")) }

  def read? = read_at.present?

  # Keeps the first read time; later visits do not move it.
  def mark_read!
    touch(:read_at) unless read?
  end

  # Starts summarising in the language unless a summary there is done or
  # already in progress; a failed one is retried. Safe against double presses.
  def request_summary(language)
    summary = find_or_create_summary(language)
    SummarizeArticleJob.perform_later(summary) if summary.previously_new_record? || summary.retry_if_failed
  end

  # Feeds are untrusted, so only http(s) URLs with a host are safe to send a browser to.
  def web_url? = WebUrl.valid?(url)

  private
    # A concurrent press may create the same summary between our lookup and
    # insert; the unique index (or its validation) then means it now exists.
    def find_or_create_summary(language)
      summaries.find_by(language:) || summaries.create!(language:)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      summaries.find_by!(language:)
    end
end
