# frozen_string_literal: true

module PyriteExtensions
  class AdminExtensionDetailSerializer < AdminExtensionSerializer
    attributes :summary, :releases, :events

    def releases
      object.releases_newest_first.map do |release|
        {
          version: release.version,
          published_at: release.published_at,
          downloads_count: release.downloads_count,
          sha256: release.sha256,
          has_package: release.upload_id.present?,
          moderation_level: release.moderation_level,
          moderation_severity: release.moderation_severity,
          moderation_message: release.moderation_message,
        }
      end
    end

    # Newest first, with the staff-only notes that are never sent to the IDE.
    def events
      object.moderation_events.sort_by(&:created_at).reverse.map do |event|
        {
          id: event.id,
          created_at: event.created_at,
          actor_username: event.actor.username,
          version: event.release&.version,
          level: event.level,
          severity: event.severity,
          public_message: event.public_message,
          internal_note: event.internal_note,
        }
      end
    end
  end
end
