FactoryBot.define do
  factory :user do
    sequence(:google_uid) { |n| "google-uid-#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
  end
end
