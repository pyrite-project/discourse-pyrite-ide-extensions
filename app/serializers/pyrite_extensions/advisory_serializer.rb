# frozen_string_literal: true

module PyriteExtensions
  class AdvisorySerializer < ApplicationSerializer
    attributes :ext_id, :version, :installable, :moderation

    def ext_id
      object.extension.ext_id
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
