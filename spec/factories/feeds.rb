FactoryBot.define do
  factory :feed do
    user
    title { "Example Blog" }
    sequence(:url) { |n| "https://example.com/feed#{n}.xml" }
  end
end
