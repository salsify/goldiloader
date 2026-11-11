# frozen_string_literal: true

module Goldiloader
  # Tracks the lazy loads of the records loaded together, and of the records they lazily load in turn,
  # to tell when eager loading an association would have saved a query. Keys are classes and association
  # names, and owners are tracked by class and id, so records cached with Marshal can still be dumped and
  # records loaded again, e.g. by a reload, count as the same owner.
  class SuggestionTracker
    def initialize
      @first_owners = {}
      @suggested = Set.new
      @nested_trackers = {}
    end

    # True the first time a second record loads the association
    def second_owner?(key, owner)
      return false if @suggested.include?(key)

      owner_key = [owner.class, owner.id]
      first_owner_key = (@first_owners[key] ||= owner_key)
      return false if first_owner_key == owner_key

      @first_owners.delete(key)
      @suggested << key
      true
    end

    def nested_tracker(key)
      @nested_trackers[key] ||= SuggestionTracker.new
    end
  end
end
