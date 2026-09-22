class User < ApplicationRecord
  has_many :feeds, dependent: :destroy
  has_many :articles, through: :feeds

  validates :google_uid, presence: true, uniqueness: true
  validates :email, presence: true
  validates :name, presence: true
end
