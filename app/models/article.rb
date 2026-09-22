class Article < ApplicationRecord
  belongs_to :feed

  # Some feeds omit publication dates; those articles fall back to when they were fetched.
  scope :newest_first, -> { order(Arel.sql("COALESCE(articles.published_at, articles.created_at) DESC")) }

  validates :guid, presence: true, uniqueness: { scope: :feed_id }
  validates :url, presence: true
  validates :title, presence: true
end
