# frozen_string_literal: true

class PyriteExtensions::Extension::Policy::TakedownIsFinal < Service::PolicyBase
  delegate :extension, :release, :params, to: :context, private: true

  # A takedown purges the stored packages, so lifting it would leave a release
  # that claims to be available and has nothing to serve.
  def call
    (release || extension).moderation_level != "takedown" || params.level == "takedown"
  end

  def reason
    I18n.t("pyrite_extensions.errors.takedown_is_final")
  end
end
