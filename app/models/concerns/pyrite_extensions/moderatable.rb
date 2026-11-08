# frozen_string_literal: true

module PyriteExtensions
  # npm-style warning levels. Higher means more severe; the effective state of a version
  # is the most severe of its own state and its extension's state.
  module Moderatable
    extend ActiveSupport::Concern

    LEVELS = {
      none: 0,
      notice: 1,
      deprecated: 2,
      advisory: 3,
      withdrawn: 4,
      delisted: 5,
      takedown: 6
    }.freeze
    SEVERITIES = %w[low moderate high critical].freeze
    BLOCKING_LEVELS = %i[withdrawn delisted takedown].freeze
    # Delisting hides a whole package, so it has no meaning for a single version.
    VERSION_LEVELS = LEVELS.keys - [:delisted]

    included do
      enum :moderation_level, LEVELS, prefix: :moderation
      validates :moderation_severity, inclusion: { in: SEVERITIES }, if: :moderation_advisory?
      validates :moderation_severity, absence: true, unless: :moderation_advisory?
    end

    def blocks_install?
      BLOCKING_LEVELS.include?(moderation_level.to_sym)
    end

    def moderated?
      !moderation_none?
    end
  end
end
