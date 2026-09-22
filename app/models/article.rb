class Article < ApplicationRecord
  belongs_to :feed
  has_many :summaries, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }
  validates :url, presence: true
  validates :title, presence: true

  # sorted_at is published_at, or the fetch time for feeds that omit dates
  # (a generated column); id breaks ties so the order is total for paging.
  scope :newest_first, -> { order(sorted_at: :desc, id: :desc) }
  # Keyset page: everything after the given article in newest_first order.
  scope :older_than, ->(article) {
    where("(articles.sorted_at, articles.id) < (?, ?)", article.sorted_at, article.id)
  }

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
