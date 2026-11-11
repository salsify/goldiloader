# frozen_string_literal: true

module Goldiloader
  # Tracks the lazy loads of the records loaded together, and of the records they lazily load in turn,
  # to tell when eager loading an association would have saved a query. Keyed by the class defining the
  # association and its name, rather than by reflection, so records cached with Marshal can still be dumped.
  class SuggestionTracker
    def initialize
      @first_owners = {}
      @suggested = Set.new
      @nested_trackers = {}
    end

    # True the first time a second record loads the association
    def second_owner?(reflection, owner)
      key = [reflection.active_record, reflection.name]
      return false if @suggested.include?(key)

      first_owner = (@first_owners[key] ||= owner)
      return false if first_owner.equal?(owner)

      @first_owners.delete(key)
      @suggested << key
      true
    end

    def nested_tracker(reflection)
      @nested_trackers[[reflection.active_record, reflection.name]] ||= SuggestionTracker.new
    end
  end
end
