# frozen_string_literal: true

module Goldiloader
  # Tracks the lazy loads of the records loaded together, and of the records they lazily load in turn,
  # to tell when eager loading an association would have saved a query
  class SuggestionTracker
    SUGGESTED = Object.new.freeze

    def initialize
      @first_owner_by_reflection = {}
      @nested_tracker_by_reflection = {}
    end

    def second_owner?(reflection, owner)
      first_owner = @first_owner_by_reflection[reflection]
      if first_owner.nil?
        @first_owner_by_reflection[reflection] = owner
        false
      elsif first_owner.equal?(owner) || first_owner.equal?(SUGGESTED)
        false
      else
        @first_owner_by_reflection[reflection] = SUGGESTED
        true
      end
    end

    def nested_tracker(reflection)
      @nested_tracker_by_reflection[reflection] ||= SuggestionTracker.new
    end
  end
end
