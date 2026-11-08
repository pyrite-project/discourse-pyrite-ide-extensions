# frozen_string_literal: true

module PyriteExtensions
  class ReleaseSerializer < ApplicationSerializer
    attributes :extension_id,
               :version,
               :manifest,
               :artifact,
               :changelog,
               :published_at,
               :installable,
               :moderation

    def extension_id
      object.extension.ext_id
    end

    def manifest
      object.manifest.merge(
        'platforms' => object.manifest_platforms,
        'permissions' => object.manifest_permissions,
      )
    end

    def artifact
      { sha256: object.sha256, size: object.size }
    end

    def installable
      !object.blocks_install?
    end

    def moderation
      state = object.effective_state
      { level: state.level, severity: state.severity, message: state.message, scope: state.scope }
    end
  end
end
