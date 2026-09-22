FactoryBot.define do
  factory :summary do
    article
    language { "ja" }

    trait :done do
      state { :done }
      body { "要約本文" }
    end

    trait :failed do
      state { :failed }
      failure_reason { "api_error" }
    end
  end
end
