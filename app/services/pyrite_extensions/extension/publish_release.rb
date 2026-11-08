# frozen_string_literal: true

class PyriteExtensions::Extension::PublishRelease
  include Service::Base

  params do
    attribute :ext_id, :string
    attribute :upload_id, :integer
    attribute :changelog, :string

    validates :ext_id, :upload_id, presence: true
  end

  model :extension
  policy :can_manage
  policy :scope_available
  policy :extension_not_removed
  model :upload
  model :package, :open_package
  policy :valid_package, class_name: PyriteExtensions::Extension::Policy::ValidPackage
  policy :package_belongs_to_extension,
         class_name: PyriteExtensions::Extension::Policy::PackageBelongsToExtension
  policy :version_not_published

  transaction do
    model :release, :create_release
    step :mark_latest_release
  end

  step :sync_topic

  private

  def fetch_extension(params:)
    PyriteExtensions::Extension.includes(:topic, :releases).find_by(ext_id: params.ext_id)
  end

  def can_manage(extension:, guardian:)
    guardian.can_manage_pyrite_extension?(extension)
  end

  def scope_available(extension:, guardian:)
    PyriteExtensions::Scope.available_to?(extension.ext_id, guardian.user)
  end

  # Nothing new can be added to a plugin staff have removed.
  def extension_not_removed(extension:)
    !extension.moderation_takedown?
  end

  def fetch_upload(params:, guardian:)
    PyriteExtensions::Extension::Action::FindStagedUpload.call(
      upload_id: params.upload_id,
      user: guardian.user,
    )
  end

  def open_package(upload:)
    PyriteExtensions::Extension::Action::OpenPackage.call(upload:)
  end

  def version_not_published(extension:, package:)
    extension.releases.none? { |release| release.version == package.manifest.version }
  end

  def create_release(params:, extension:, package:, upload:)
    PyriteExtensions::Release.create(
      extension:,
      version: package.manifest.version,
      upload:,
      sha256: package.sha256,
      size: package.size,
      manifest: package.manifest.to_h,
      changelog: params.changelog.presence,
      published_at: Time.zone.now,
    )
  end

  # The newest by semantic version, not by date: a backport published later
  # must not displace a higher release as the one people install by default.
  def mark_latest_release(extension:)
    extension.update!(latest_release: extension.releases.reload.max_by(&:semver))
  end

  def sync_topic(extension:)
    PyriteExtensions::Extension::Action::SyncTopic.call(extension:)
  end
end
