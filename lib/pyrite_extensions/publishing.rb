# frozen_string_literal: true

module PyriteExtensions
  # Marks the one trusted code path (publishing through the registry) that may start a topic in the
  # registry category, which the Guardian otherwise reserves for staff.
  module Publishing
    KEY = :pyrite_extensions_publishing

    def self.allow_topic_creation
      previous = Thread.current[KEY]
      Thread.current[KEY] = true
      yield
    ensure
      Thread.current[KEY] = previous
    end

    def self.active?
      Thread.current[KEY] == true
    end
  end
end
