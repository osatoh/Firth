FactoryBot.define do
  factory :article do
    feed
    sequence(:guid) { |n| "https://example.com/posts/#{n}" }
    url { guid }
    title { "Example Post" }
    published_at { Time.current }
  end
end
