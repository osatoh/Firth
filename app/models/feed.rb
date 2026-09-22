class Feed < ApplicationRecord
  # Bounds what the operator pays to fetch and store per user (spec 1.5).
  LIMIT_PER_USER = 100

  belongs_to :user
  has_many :articles, dependent: :delete_all

  validates :title, presence: true
  validates :url, presence: true, uniqueness: { scope: :user_id }
  validate :url_must_be_http
  validate :within_user_limit, on: :create

  before_validation :normalize_url
  # Fetch right away instead of waiting for the next scheduled run (spec 2.3.5).
  # A new record's URL counts as changed, so this also covers creation.
  after_commit :enqueue_fetch, if: :saved_change_to_url?

  # Two concurrent saves can both clear the uniqueness validation; the unique
  # index catches the loser. Report that as the same error the validation
  # gives, so callers need not handle the race themselves.
  def save(**)
    super
  rescue ActiveRecord::RecordNotUnique
    errors.add(:url, :taken)
    false
  end

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

      uri = WebUrl.parse(url) or return

      uri.host = uri.host.downcase
      uri.path = "/" if uri.path.empty?
      self.url = uri.to_s
    end

    # Validations run inside the save transaction, so locking the user row
    # here serialises concurrent creates for the same user: the second one
    # waits, then counts the first one's feed. Users are few and creates rare,
    # so a row lock is simpler than a counter column or a DB trigger.
    def within_user_limit
      return unless user

      user.lock!
      errors.add(:base, :limit_reached, count: LIMIT_PER_USER) if user.remaining_feed_count.zero?
    end

    # Only checks that the URL is shaped like something we can fetch.
    # Whether it actually resolves is the fetch job's concern (task 2.2).
    def url_must_be_http
      errors.add(:url, :invalid) unless url.blank? || WebUrl.valid?(url)
    end
end
