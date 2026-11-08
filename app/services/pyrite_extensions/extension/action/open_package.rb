# frozen_string_literal: true

# Opens the package stored for an upload, or returns nil when the file is not
# there. The caller checks Package#valid?.
class PyriteExtensions::Extension::Action::OpenPackage < Service::ActionBase
  option :upload

  def call
    Discourse.store.external? ? open_downloaded : open_local
  end

  private

  # The local store would otherwise fetch the file back over HTTP from this very site.
  def open_local
    path = Discourse.store.path_for(upload)
    PyriteExtensions::Package.open(path) if path && File.exist?(path)
  end

  # The Tempfile must stay referenced until the package has been read, or the
  # file can be deleted underneath it.
  def open_downloaded
    max_bytes = SiteSetting.pyrite_extensions_max_package_size_mb.megabytes
    file = Discourse.store.download(upload, max_file_size_kb: max_bytes)
    PyriteExtensions::Package.open(file.path) if file
  end
end
