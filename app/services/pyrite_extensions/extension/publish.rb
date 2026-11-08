# frozen_string_literal: true

class PyriteExtensions::Extension::Publish
  include Service::Base

  params do
    attribute :upload_id, :integer
    attribute :title, :string
    attribute :summary, :string
    attribute :repo_url, :string
    attribute :homepage_url, :string
    attribute :license, :string
    attribute :tags, :array, default: -> { [] }
    attribute :description, :string
    attribute :changelog, :string

    validates :upload_id, :title, :summary, presence: true
    validates :summary, length: { maximum: PyriteExtensions::Extension::MAX_SUMMARY_LENGTH }
    validates :repo_url,
              :homepage_url,
              format: {
                with: PyriteExtensions::Extension::URL_PATTERN,
              },
              allow_blank: true
  end

  policy :can_publish
  model :upload
  model :package, :open_package
  policy :valid_package, class_name: PyriteExtensions::Extension::Policy::ValidPackage

  try do
    transaction do
      model :extension, :create_extension
      model :release, :create_release
      step :mark_latest_release
      model :topic, :create_topic
      step :link_topic
    end
  end

  private

  def can_publish(guardian:)
    guardian.can_publish_pyrite_extension?
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

  def create_extension(params:, package:, guardian:)
    PyriteExtensions::Extension.create(
      ext_id: package.manifest.id,
      name: package.manifest.name,
      summary: params.summary,
      repo_url: params.repo_url.presence,
      homepage_url: params.homepage_url.presence,
      license: params.license.presence,
      owner: guardian.user,
    )
  end

  def create_release(extension:, package:, upload:, params:)
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

  def mark_latest_release(extension:, release:)
    extension.update!(latest_release: release)
  end

  def create_topic(params:, extension:, guardian:)
    PyriteExtensions::Extension::Action::CreateTopic.call(
      author: guardian.user,
      title: params.title,
      raw: PyriteExtensions::ManagedBlock.compose(extension, params.description),
      tags: params.tags,
    )
  end

  def link_topic(extension:, topic:)
    extension.update!(topic:)
  end
end
