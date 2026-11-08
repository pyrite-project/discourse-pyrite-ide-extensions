# frozen_string_literal: true

module PyriteExtensions
  class ReleaseSerializer < ApplicationSerializer
    attributes :ext_id,
               :name,
               :version,
               :sha256,
               :size,
               :type,
               :platforms,
               :permissions,
               :author,
               :changelog,
               :published_at,
               :download_url,
               :installable,
               :moderation

    def ext_id
      object.extension.ext_id
    end

    def name
      object.extension.name
    end

    def type
      object.manifest['type']
    end

    def platforms
      object.manifest_platforms
    end

    def permissions
      object.manifest_permissions
    end

    def author
      object.manifest['author']
    end

    def download_url
      "#{Discourse.base_url}/pyrite/api/v1/extensions/#{ext_id}/versions/#{object.version}/package.pyrix"
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
