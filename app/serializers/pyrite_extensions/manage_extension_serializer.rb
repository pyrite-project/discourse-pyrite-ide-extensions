# frozen_string_literal: true

module PyriteExtensions
  # What the manage page needs beyond the public view: per-release numbers and
  # moderation text, and what the viewer is allowed to do.
  class ManageExtensionSerializer < ExtensionSerializer
    attributes :can_manage, :staff, :withdraw_window_hours, :release_details

    def can_manage
      true
    end

    def staff
      scope.is_staff?
    end

    def withdraw_window_hours
      SiteSetting.pyrite_extensions_author_withdraw_window_hours
    end

    def release_details
      object.releases_newest_first.map do |release|
        {
          version: release.version,
          published_at: release.published_at,
          downloads_count: release.downloads_count,
          size: release.size,
          has_package: release.upload_id.present?,
          moderation_level: release.moderation_level,
          moderation_severity: release.moderation_severity,
          moderation_message: release.moderation_message,
        }
      end
    end
  end
end
