# frozen_string_literal: true

module Goldiloader
  # Tracks the lazy loads of the records loaded together, and of the records they lazily load in turn,
  # to tell when eager loading an association would have saved a query. Keyed by association name rather
  # than reflection so records cached with Marshal can still be dumped.
  class SuggestionTracker
    SUGGESTED = :suggested

    def initialize
      @first_owner_by_name = {}
      @nested_tracker_by_name = {}
    end

    def second_owner?(reflection, owner)
      first_owner = (@first_owner_by_name[reflection.name] ||= owner)
      return false if first_owner.equal?(owner) || first_owner.equal?(SUGGESTED)

      @first_owner_by_name[reflection.name] = SUGGESTED
      true
    end

    def nested_tracker(reflection)
      @nested_tracker_by_name[reflection.name] ||= SuggestionTracker.new
    end
  end
end
