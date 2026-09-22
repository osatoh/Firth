class Article < ApplicationRecord
  belongs_to :feed

  # Some feeds omit publication dates; those articles fall back to when they were fetched.
  scope :newest_first, -> { order(Arel.sql("COALESCE(articles.published_at, articles.created_at) DESC")) }

  def read? = read_at.present?

  # Keeps the first read time; later visits do not move it.
  def mark_read!
    touch(:read_at) unless read?
  end

  # Feeds are untrusted, so only http(s) URLs with a host are safe to send a browser to.
  def web_url? = WebUrl.valid?(url)

  validates :guid, presence: true, uniqueness: { scope: :feed_id }
  validates :url, presence: true
  validates :title, presence: true
end
