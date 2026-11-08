# frozen_string_literal: true

module PyriteExtensions
  class Release < ActiveRecord::Base
    include Moderatable

    self.table_name = 'pyrite_extension_releases'

    EffectiveState = Data.define(:level, :severity, :message, :scope)

    belongs_to :extension, class_name: 'PyriteExtensions::Extension', inverse_of: :releases
    belongs_to :upload, optional: true

    validates :version, presence: true, length: { maximum: 64 }
    validates :version,
              uniqueness: {
                scope: :extension_id,
                message: ->(*) { I18n.t('pyrite_extensions.errors.version_exists') }
              }
    validates :sha256, format: { with: /\A\h{64}\z/ }
    validate :version_is_semver
    validate :moderation_level_applies_to_versions

    def semver
      SemVer.parse(version)
    end

    def manifest_permissions
      manifest.fetch('permissions', [])
    end

    def manifest_platforms
      manifest.fetch('platforms', [])
    end

    # The most severe of the version's own state and its extension's. On a tie the version wins,
    # so a version-specific message is shown rather than the package-wide one.
    def effective_state
      source =
        [self, extension].max_by do |record|
          Moderatable::LEVELS.fetch(record.moderation_level.to_sym)
        end
      EffectiveState.new(
        level: source.moderation_level.to_sym,
        severity: source.moderation_severity,
        message: source.moderation_message,
        scope: source.is_a?(Release) ? :release : :package
      )
    end

    def blocks_install?
      Moderatable::BLOCKING_LEVELS.include?(effective_state.level)
    end

    private

    def version_is_semver
      errors.add(:version, :invalid) if version.present? && semver.nil?
    end

    def moderation_level_applies_to_versions
      return if Moderatable::VERSION_LEVELS.include?(moderation_level.to_sym)

      errors.add(:moderation_level, :inclusion)
    end
  end
end
