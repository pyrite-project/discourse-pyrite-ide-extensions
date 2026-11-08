# frozen_string_literal: true

class PyriteExtensions::Extension::Policy::PackageBelongsToExtension < Service::PolicyBase
  delegate :extension, :package, to: :context, private: true

  # The id in plugin.toml is the plugin's identity: a package for another id
  # would silently publish a different plugin under this one's topic.
  def call
    package.manifest.id == extension.ext_id
  end

  def reason
    I18n.t("pyrite_extensions.errors.package_for_other_extension", ext_id: extension.ext_id)
  end
end
