class Article < ApplicationRecord
  belongs_to :feed

  validates :guid, presence: true, uniqueness: { scope: :feed_id }
  validates :url, presence: true
  validates :title, presence: true
end
