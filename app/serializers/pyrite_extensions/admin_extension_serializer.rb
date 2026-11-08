# frozen_string_literal: true

module PyriteExtensions
  class AdminExtensionSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :owner_username,
               :topic_id,
               :latest_version,
               :releases_count,
               :flagged_releases_count,
               :moderation_level,
               :moderation_severity,
               :moderation_message,
               :updated_at

    def id
      object.ext_id
    end

    def owner_username
      object.owner.username
    end

    def latest_version
      object.latest_release&.version
    end

    def releases_count
      object.releases.size
    end

    def flagged_releases_count
      object.releases.count(&:moderated?)
    end
  end
end
