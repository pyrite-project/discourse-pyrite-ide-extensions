# frozen_string_literal: true

class PyriteExtensions::Extension::UploadPackage
  include Service::Base

  EXTENSIONS = %w[.pyrix .zip].freeze

  params do
    attribute :file

    validate :uploaded_package_file

    def uploaded_package_file
      return errors.add(:file, :blank) if file.blank?
      if !file.respond_to?(:tempfile) ||
         EXTENSIONS.exclude?(File.extname(file.original_filename.to_s).downcase)
        return errors.add(:file, I18n.t('pyrite_extensions.errors.file_type'))
      end

      return if file.size <= SiteSetting.pyrite_extensions_max_package_size_mb.megabytes

      errors.add(:file, I18n.t('pyrite_extensions.errors.file_too_big'))
    end
  end

  policy :can_publish
  model :package, :open_package
  policy :valid_package, class_name: PyriteExtensions::Extension::Policy::ValidPackage
  model :extension, :find_extension, optional: true
  policy :extension_id_available
  policy :version_not_published
  model :upload, :store_upload

  private

  def can_publish(guardian:)
    guardian.can_publish_pyrite_extension?
  end

  def open_package(params:)
    PyriteExtensions::Package.open(params.file.tempfile.path)
  end

  def find_extension(package:)
    PyriteExtensions::Extension.find_by(ext_id: package.manifest.id)
  end

  def extension_id_available(extension:, guardian:)
    extension.nil? || guardian.can_manage_pyrite_extension?(extension)
  end

  def version_not_published(extension:, package:)
    extension.nil? || !extension.releases.exists?(version: package.manifest.version)
  end

  def store_upload(params:, guardian:)
    UploadCreator.new(
      params.file.tempfile,
      params.file.original_filename,
      type: 'pyrite_extension',
      skip_validations: true
    ).create_for(guardian.user.id)
  end
end
