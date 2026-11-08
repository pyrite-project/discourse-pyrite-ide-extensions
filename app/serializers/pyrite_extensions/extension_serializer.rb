# frozen_string_literal: true

module PyriteExtensions
  class ExtensionSerializer < ApplicationSerializer
    attributes :ext_id,
               :name,
               :summary,
               :repo_url,
               :homepage_url,
               :license,
               :owner_username,
               :topic_url,
               :latest_version,
               :versions,
               :moderation

    def owner_username
      object.owner.username
    end

    def include_topic_url?
      object.topic.present?
    end

    def topic_url
      object.topic.url
    end

    def latest_version
      object.latest_release&.version
    end

    def versions
      object.releases_newest_first.map do |release|
        state = release.effective_state
        { version: release.version, published_at: release.published_at, level: state.level }
      end
    end

    def moderation
      {
        level: object.moderation_level,
        severity: object.moderation_severity,
        message: object.moderation_message
      }
    end
  end
end
