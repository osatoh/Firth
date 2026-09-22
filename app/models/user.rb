class User < ApplicationRecord
  SUMMARY_LANGUAGES = %w[ja en zh ko].freeze
  ANTHROPIC_API_KEY_PREFIX = "sk-ant-".freeze

  has_many :feeds, dependent: :destroy
  has_many :articles, through: :feeds

  encrypts :anthropic_api_key

  normalizes :anthropic_api_key, with: ->(key) { key.strip.presence }

  validates :google_uid, presence: true, uniqueness: true
  validates :email, presence: true
  validates :name, presence: true
  validates :summary_language, inclusion: { in: SUMMARY_LANGUAGES }
  # Only a format check; whether the key actually works is found out when summarising.
  validates :anthropic_api_key, format: { with: /\A#{ANTHROPIC_API_KEY_PREFIX}\S+\z/, message: :anthropic_prefix }, allow_nil: true

  # Enough to recognise which key is stored without ever showing it.
  def masked_anthropic_api_key
    "#{ANTHROPIC_API_KEY_PREFIX}…#{anthropic_api_key.last(4)}" if anthropic_api_key
  end
end
