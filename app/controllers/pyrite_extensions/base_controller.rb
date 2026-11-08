# frozen_string_literal: true

module PyriteExtensions
  class BaseController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    private

    def find_visible_extension!
      extension = Extension.includes(:owner, :topic, :releases).find_by(ext_id: params[:ext_id])
      raise Discourse::NotFound if extension.nil? || !guardian.can_see_pyrite_extension?(extension)

      extension
    end

    def find_visible_release!(extension)
      release = extension.releases.find { |candidate| candidate.version == params[:version] }
      raise Discourse::NotFound if release.nil? || (release.moderation_takedown? && !guardian.is_staff?)

      release
    end
  end
end
