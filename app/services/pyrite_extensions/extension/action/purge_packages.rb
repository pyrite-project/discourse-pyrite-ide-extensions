# frozen_string_literal: true

# Deletes the stored package files of a taken-down release, or of every release
# when the whole package is taken down. The release records stay, as the audit
# trail and so the IDE can still be told they were removed.
class PyriteExtensions::Extension::Action::PurgePackages < Service::ActionBase
  option :extension
  option :release, optional: true

  def call
    releases = release ? [release] : extension.releases.to_a
    releases.each { |purged| purge(purged) }
  end

  private

  def purge(purged)
    upload = purged.upload
    purged.update_columns(upload_id: nil)
    return if upload.nil?

    # Uploads are shared between identical files, so another release may still
    # point at this one.
    return if PyriteExtensions::Release.exists?(upload_id: upload.id)

    Discourse.store.remove_upload(upload)
    upload.destroy!
  end
end
