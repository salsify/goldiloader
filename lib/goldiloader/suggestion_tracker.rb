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

    # True the first time a second record loads the association. A polymorphic belongs_to, whose key ends with its
    # target class, is suggested once for all its target classes.
    def second_owner?(key, owner)
      association_key = key.first(2)
      return false if @suggested.include?(association_key)

      # Records loaded without their id, or part of a composite one, are told apart in memory
      owner_id = owner.id
      owner_key = owner_id.nil? || Array(owner_id).include?(nil) ? owner.object_id : [owner.class, owner_id]
      first_owner_key = (@first_owners[key] ||= owner_key)
      return false if first_owner_key == owner_key

      @first_owners.delete(key)
      @suggested << association_key
      true
    end

    def nested_tracker(key)
      @nested_trackers[key] ||= SuggestionTracker.new
    end
  end
end
