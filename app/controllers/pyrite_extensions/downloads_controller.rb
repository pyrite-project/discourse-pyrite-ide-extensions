# frozen_string_literal: true

module PyriteExtensions
  # Both package formats are the same bytes; the requested extension only changes the file name.
  class DownloadsController < BaseController
    def show
      extension = find_visible_extension!
      release = find_visible_release!(extension)
      raise Discourse::NotFound if release.upload.nil?
      if refused?(release)
        return render_json_error(release.effective_state.message.to_s, status: 410)
      end

      Release.increment_counter(:downloads_count, release.id)
      deliver(release.upload, "#{file_stem(extension.ext_id)}-#{release.version}.#{params[:package_format]}")
    end

    private

    # Scoped ids contain a slash, which cannot appear in a file name.
    def file_stem(ext_id)
      ext_id.delete_prefix("@").tr("/", "-")
    end

    def refused?(release)
      release.blocks_install? && !guardian.is_staff?
    end

    def deliver(upload, filename)
      if Discourse.store.external?
        redirect_to Discourse.store.url_for(upload, force_download: true), allow_other_host: true
      else
        send_file Discourse.store.path_for(upload),
                  filename:,
                  type: "application/zip",
                  disposition: "attachment"
      end
    end
  end
end
