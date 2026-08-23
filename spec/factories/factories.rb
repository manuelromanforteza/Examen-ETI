FactoryBot.define do
  factory :tournament_session do
    rounds_per_match { 10 }
    status { "collecting" }
  end

  factory :strategy do
    sequence(:key) { |n| Strategy::KEYS[n % Strategy::KEYS.length] }
    sequence(:name) { |n| "Strategy #{n}" }
    description { "Test description" }
    pros { "Test pros" }
    cons { "Test cons" }

    # Named factory for each real strategy key
    Strategy::KEYS.each do |k|
      trait k.to_sym do
        key { k }
        name { k.humanize }
      end
    end
  end

  factory :group do
    association :session, factory: :tournament_session
    sequence(:name) { |n| "Group #{n}" }
    pin { "1234" }
  end

  factory :selection do
    association :group
    association :strategy
  end
end
